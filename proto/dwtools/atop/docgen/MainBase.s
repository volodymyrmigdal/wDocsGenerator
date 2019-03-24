( function _MainBase_s_() {

'use strict';

/**
 * Utility to generate documentation from jsdoc annotated source code.
  @module Tools/wDocGenerator
*/

/**
 * @file Main.base.s
 */

if( typeof module !== 'undefined' )
{

  require( './IncludeBase.s' );

  var jsdoc2md = require('jsdoc-to-markdown')
  var ddata = require( 'dmd/helpers/ddata.js' )
  var state = require( 'dmd/lib/state.js' );

  var arrayify = require('array-back');
  var where = require('test-value').where;
}

//

let _ = _global_.wTools;
let Parent = null;
let Self = function wDocGenerator( o )
{
  return _.instanceConstructor( Self, this, arguments );
}

Self.shortName = 'DocGenerator';

// --
// routines
// --

function init( o )
{
  let self = this;

  _.assert( arguments.length === 0 || arguments.length === 1 );

  if( !self.logger )
  self.logger = new _.Logger({ output : console });

  if( !self.provider )
  self.provider = _.FileProvider.HardDrive();

  _.instanceInit( self );
  Object.preventExtensions( self );

  if( o )
  self.copy( o );
}

//

function finit()
{
  return _.Copyable.prototype.finit.apply( this, arguments );
}

//

function form( e )
{
  let self = this;

  _.assert( arguments.length === 0 || arguments.length === 1 );

  let appArgs;

  if( !e )
  {
    appArgs = _.appArgs();
  }
  else
  {
    appArgs =
    {
      subject : e.argument,
      map : e.propertiesMap
    }
  }

  _.appArgsReadTo
  ({
    dst : self,
    namesMap :
    {
      verbosity : 'verbosity',
      v : 'verbosity',
      outPath : 'outPath',
      out : 'outPath',
      docsify : 'docsify',
      includingManuals : 'includingManuals',
      includingTutorials : 'includingTutorials',
      manualsPath : 'manualsPath',
      manuals: 'manualsPath',
      tutorialsPath : 'tutorialsPath',
      tutorials : 'tutorialsPath'
    },
    propertiesMap : appArgs.map
  });

  _.sure( _.strDefined( appArgs.subject ), '{-sourcesPath-} needs value, please pass a subject' );

  self.sourcesPath = appArgs.subject;

  self.pathsResolve();

  _.assert( self.provider.fileExists( self.sourcesPath ), 'Provided sourcesPath doesn`t exist:', self.sourcesPath );

  if( self.includeAny )
  self.includeAny = new RegExp( self.includeAny );
  if( self.excludeAny )
  self.excludeAny = new RegExp( self.excludeAny );
}

//

function pathsResolve()
{
  let self = this;
  let path = self.provider.path;

  self.sourcesPath = path.resolve( path.current(),self.sourcesPath );
  self.manualsPath = path.resolve( path.current(),self.manualsPath );
  self.outPath = path.resolve( path.current(),self.outPath );

  if( !self.env )
  self.env = _.TemplateTreeEnvironment({ tree : self });
  self.env.pathsNormalize();

  self.outReferencePath = path.resolve( path.current(),self.outReferencePath );
  self.outManualsPath = path.resolve( path.current(),self.outManualsPath );
  self.outTutorialsPath = path.resolve( path.current(),self.outTutorialsPath );
}

//

//

function templateDataRead()
{
  let self = this;
  let logger = self.logger;
  let path = self.provider.path;

  let files = self.provider.filesFind
  ({
    filePath : self.sourcesPath,
    filter :
    {
      ends : [ '.s','.ss','.js' ],
      maskAll :
      {
        includeAny : self.includeAny,
        excludeAny : self.excludeAny
      }
    },
    includingTransient : 1,
	  includingDirs : 0,
    outputFormat : 'absolute',
    recursive : 2,
  });

  _.assert( files.length, 'No files found at sourcesPath:', self.sourcesPath )

  try
  {
    self.templateData = jsdoc2md.getTemplateDataSync
    ({
      files : path.s.nativize( files ),
      configure : path.nativize( path.join( __dirname,  'conf/doc.json' ) )
    })
  }
  catch( err )
  {
    _.errLogOnce( _.err( 'jsdoc2md: Error during parse:', err ) );
  }

  // logger.log( _.toStr( self.parsedTemplateData, { jsLike : 1 } ) )
}

//

function docsifyAppBaseCopy()
{
  let self = this;
  let path = self.provider.path;

  _.assert( arguments.length === 0 );

  let docsifyAppPath = path.join( __dirname, 'docsify-app' );

  _.sure( self.provider.fileExists( docsifyAppPath ) );

  self.provider.filesReflect({ reflectMap : { [ docsifyAppPath ] : self.outPath } });

  return true;
}

//

function markdownGenerate()
{
  let self = this;
  let path = self.provider.path;

  renderIdentifiers({ kind : 'module' });
  renderIdentifiers({ kind : 'class' });
  renderIdentifiers({ kind : 'namespace' });

  /* index */

  let partial = path.s.join( __dirname, 'templates/index/**' )
  let helper = path.s.join( __dirname, 'helpers/**' );

  let index = jsdoc2md.renderSync
  ({
    data : self.templateData,
    partial: path.s.nativize( partial ),
    helper: path.s.nativize( helper ),
    template : '{{>index}}'
  })

  let filePath = path.join( self.outPath, 'README.md' );
  self.provider.fileWrite( filePath,index );

  /* search index */

  searchIndexMake();

  /*  */

  function identifiers( hash )
  {
    let query = {};

    for (var p in hash )
    {
      if ( /^-/.test( p ) )
      {
        query[ p.replace( /^-/, '!') ] = hash[ p ];
      }
      else if ( /^_/.test( p ) )
      {
        query[ p.replace( /^_/, '' ) ] = new RegExp( hash[ p ] );
      }
      else
      {
        query[ p ] = hash[ p ];
      }
    }

    let result = arrayify( self.templateData );

    result = result.filter( where( query ) );
    result = result.filter( ( e ) => !e.ignore && e.access !== 'private' );

    return result;
  }

  /*  */

  function parentObject( e )
  {
    return arrayify( self.templateData ).find( where( { id: e.memberof } ) );
  }

  /*  */

  function escapedAnchor( e )
  {
    let anchor = ddata.anchorName.call( e, state.options );
    anchor = anchor.replace( /[\.\+\/]/g, '_' );
    return anchor;
  }

  /*  */

  function isPrivate ( e ) { return e.access === 'private' }

  /*  */

  function renderIdentifiers( hash )
  {
    _.assert( hash.kind );

    let result = identifiers( hash );

    let partial = path.s.join( __dirname, 'templates/main/**' )
    let helper = path.s.join( __dirname, 'helpers/**' );

    let o =
    {
      data : self.templateData,
      partial: path.s.nativize( partial ),
      helper: path.s.nativize( helper ),
      template : '{{>main}}'
    }

    result.forEach( ( e ) =>
    {
      state.currentId = e.id;

      let result = jsdoc2md.renderSync( o );

      let fileName = e.name /* + '-' + e.meta.filename + '-' + e.order */ + '.md';
      let filePath = path.join( self.outReferencePath, hash.kind, fileName );
      self.provider.fileWrite( filePath, result );
    })
  }

  /*  */

  function searchIndexMake()
  {
    let searchIndex = Object.create( null );

    self.templateData.forEach( ( e ) =>
    {
      if( isPrivate( e ) )
      return;

      let anchor = escapedAnchor( e );
      let parent = parentObject( e );

      let id = e.name;

      if( parent )
      id = parent.name + '.' + e.name;

      let url;

      if( parent )
      {
        url = `/#/Reference/${parent.kind}/${parent.name}?id=${anchor}`;
      }
      else
      {
        url = `/#/Reference/${e.kind}/${e.name}?id=${anchor}`;
      }

      searchIndex[ id ] = { title : id, url : url };
    })

    let searchIndexPath = path.join( self.outPath, 'searchIndex.json' );
    self.provider.fileWrite({ filePath : searchIndexPath, data : searchIndex, encoding : 'json.min' });
  }

}

//

function prepareManuals()
{
  let self = this;
  self.provider.filesReflect
  ({
    reflectMap : { [ self.manualsPath ] : self.outManualsPath }
  });
}

function prepareTutorials()
{
  let self = this;
  self.provider.filesReflect
  ({
    reflectMap : { [ self.tutorialsPath ] : self.outTutorialsPath }
  });
}

// --
// relations
// --

let Composes =
{

  verbosity : 1,

  sourcesPath : 'proto',
  manualsPath : 'doc/manual',
  tutorialsPath : 'doc/tutorial',

  outPath : 'out/documentation',

  includeAny : ".+\\.(js|ss|s)(doc)?$",
  excludeAny : "(^|\\/|\\.)(-|node_modules|3rd|external|test)",

  docsify : 1,

  includingManuals : 0,
  includingTutorials : 0

}

let Associates =
{
  logger : _.define.own( new _.Logger({ output : console }) ),
  provider : null
}

let Restricts =
{
  env : null,
  templateData : null,

  outReferencePath : '{{outPath}}/Reference',
  outManualsPath : '{{outPath}}/Manuals',
  outTutorialsPath : '{{outPath}}/Tutorials',
}

let Medials =
{
}

let Statics =
{
}

let Events =
{
}

let Forbids =
{
}

// --
// declare
// --

let Extend =
{

  init : init,
  finit : finit,

  form : form,

  pathsResolve : pathsResolve,

  templateDataRead : templateDataRead,
  docsifyAppBaseCopy : docsifyAppBaseCopy,
  markdownGenerate : markdownGenerate,

  prepareManuals : prepareManuals,
  prepareTutorials : prepareTutorials,

  // relations

  Composes : Composes,
  Associates : Associates,
  Restricts : Restricts,
  Medials : Medials,
  Statics : Statics,
  Events : Events,
  Forbids : Forbids,

}

//

_.classDeclare
({
  cls : Self,
  parent : Parent,
  extend : Extend,
});

_.Copyable.mixin( Self );
_.Verbal.mixin( Self );

//

if( typeof module !== 'undefined' && module !== null )
module[ 'exports' ] = Self;
wTools[ Self.shortName ] = Self;

})();