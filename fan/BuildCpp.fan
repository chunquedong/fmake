//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-2  Jed Young  Creation
//

using build

class BuildCpp : BuildScript
{

//////////////////////////////////////////////////////////////////////////
// Pod Meta-Data
//////////////////////////////////////////////////////////////////////////

  **
  ** Required name of the lib.
  **
  Str? name

  **
  ** description of pod
  **
  Str? summary

  **
  ** Required output type. Possible values are 'exe','dll','lib'
  **
  TargetType? outType

  **
  ** is debug mode
  **
  Str debug := "release"

  **
  ** default following fantom version
  **
  Version version := Version(config("buildVersion", "0"))

  **
  ** depends libs
  **
  Str[] depends := [,]

  **
  ** Required list of directories to compile.  All Cpp source
  ** files in each directory will be compiled.
  **
  Uri[] srcDirs := [`cpp/`]

  **
  ** exclude src file name
  **
  Regex? excludeSrc := null

  **
  ** List of ext libraries to link to.
  **
  Str[] extLibs := [,]

  **
  ** preproccess macro define
  **
  Str[] defines := [,]

  **
  ** List of ext include the head file
  **
  Uri[] extIncDirs := [,]

  ** List of ext lib dirs
  Uri[] extLibDirs := [,]

  **
  ** res will be copy to output directly
  **
  Uri[]? resDirs := null

  **
  ** platform depends configs item. such as 'cppflags' 'cflags'
  **
  Str:Str extConfigs := [:]

  **
  ** output, default to Env.workDir
  **
  Uri outDir := Env.cur.workDir.plus(`lib/cpp/`).uri

  **
  ** compiler name
  **
  Str compiler := config("compiler", "gcc")


//////////////////////////////////////////////////////////////////////////
// Validate
//////////////////////////////////////////////////////////////////////////

  private Void validate()
  {
    if (name == null) throw fatal("Must set name")
    if (outType == null) throw fatal("Must set outType")
    if (summary == null) throw fatal("Must set summary")
  }

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  Uri[] allDirs(Uri dir)
  {
    Uri base := scriptDir.uri
    Uri[] subs := [,]
    (base + dir).toFile.walk |File f|
    {
      if(f.isDir)
      {
        rel := f.uri.relTo(base)
        subs.add(rel)
      }
    }
    return subs
  }

  **
  ** Compile C++ source into exe or dll
  **
  @Target { help = "Compile C++ source into exe or dll" }
  Void compile()
  {
    validate

    log.info("compile [${scriptDir.name}]")
    log.indent

    compHome := config(compiler+".home", "")

    allLibDirs := this.resolveDirs2(extLibDirs)
    configLibDir := this.config("libDirs")
    if (configLibDir != null) {
      allLibDirs.addAll(this.resolveDirs2(configLibDir.split(';').map{it.toUri}))
    }

    allIncDirs := this.resolveDirs2(extIncDirs)
    configIncDir := this.config("incDirs")
    if (configIncDir != null) {
      allIncDirs.addAll(this.resolveDirs2(configIncDir.split(';').map{it.toUri}))
    }
    allIncDirs.addAll(this.resolveDirs2(srcDirs))

    allSrcDirs := [,]
    srcDirs.each {
      allSrcDirs.addAll(allDirs(it))
    }

    // compile source
    cc := CompileCpp(this)
    {
      it.outHome    = this.outDir.toFile
      it.outType    = this.outType
      it.debug      = this.debug

      it.name       = this.name
      it.summary    = this.summary
      it.depends    = this.depends.map |s->Depend| { Depend.fromStr(s) }
      it.version    = this.version
      it.srcDirs    = this.resolveDirs2(allSrcDirs)
      it.excludeSrc = this.excludeSrc
      it.scriptDir  = this.scriptDir

      it.extLibs    = this.extLibs
      it.extLibDirs = allLibDirs
      it.extIncDirs = allIncDirs
      it.compiler   = this.compiler
      it.compHome = compHome
      it.defines = this.defines
      it.extConfigs = this.extConfigs

      if(this.resDirs != null)
      {
        it.resDirs = this.resolveDirs2(this.resDirs)
      }
    }

    cc.run

    log.unindent
  }

//////////////////////////////////////////////////////////////////////////
// Full
//////////////////////////////////////////////////////////////////////////

  **
  ** Run clean, compile
  **
  @Target { help = "Run clean, compile" }
  Void full()
  {
    clean
    compile
  }

//////////////////////////////////////////////////////////////////////////
// Clean
//////////////////////////////////////////////////////////////////////////

  **
  ** Delete all intermediate and target files
  **
  @Target { help = "Delete all intermediate and target files" }
  Void clean()
  {
    log.info("clean [${scriptDir.name}]")
    log.indent
    Delete(this, outDir.toFile+`$name-$version/`).run
    log.unindent
  }


//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  **
  ** Resolve a set of URIs to files relative to scriptDir.
  **
  internal File[] resolveFiles2(Uri[] uris)
  {
    uris.map |uri->File|
    {
      f := scriptDir + uri
      if (!f.exists || f.isDir) throw fatal("Invalid file: $uri")
      return f
    }
  }

  **
  ** Resolve a set of URIs to directories relative to scriptDir.
  **
  internal File[] resolveDirs2(Uri[] uris)
  {
    uris.map |uri->File|
    {
      f := scriptDir + uri
      if (!f.exists || !f.isDir) throw fatal("Invalid dir: $uri")
      return f
    }
  }

}

**************************************************************************
** target Type
**************************************************************************

** output type
enum class TargetType
{
  ** executable file
  exe,

  ** dynamic link library
  dll,

  ** static link library
  lib
}


class Main
{

  BuildCpp? build

  private File? scriptFile

//////////////////////////////////////////////////////////////////////////

  private Uri[]? parseDirs(Str? str, Uri[]? defV := null) {
    if (str == null) return defV
    srcDirs := Uri[,]
    str.split(',').each |d| {
      if (d.endsWith("*")) {
        srcUri := d[0..<-1].toUri
        dirs := allDir(scriptFile.uri, srcUri)
        srcDirs.addAll(dirs)
      }
      else {
        srcDirs.add(d.toUri)
      }
    }
    return srcDirs
  }

  private Void getStartsWith(Str str, [Str:Str] props, [Str:Str] map) {
    props.each |v,k| {
      if (k.startsWith(str)) {
        k = k[str.size..-1]
        map[k] = v
      }
    }
  }

  private Void parse([Str:Str] props) {
    build->scriptFile = scriptFile

    build.name = props.get("name")
    build.summary = props.get("summary")

    versionStr := props.get("version")
    if (versionStr != null) build.version = Version(versionStr)

    //get depends
    props.get("depends", "").split(',').each { if (it.size>0) build.depends.add(it) }

    //get srcDirs
    //get srcDirs
    build.srcDirs = parseDirs(props.get("srcDirs"), [,])
    build.resDirs = parseDirs(props.get("resDirs"))
    excludeSrc := props.get("excludeSrc")
    if (excludeSrc != null) build.excludeSrc = Regex.fromStr(excludeSrc)

    build.outType = TargetType.fromStr(props.get("outType"))
    debug := props.get("debug")
    if (debug != null) build.debug = "release"

    build.extLibs = props.get("extLibs", "").split(',')
    build.defines = props.get("defines", "").split(',')

    build.extIncDirs = parseDirs(props.get("extIncDirs"), [,])
    build.extLibDirs = parseDirs(props.get("extLibDirs"), [,])

    //get outPodDir
    outDir := props.get("outDir", null)
    if (outDir != null) build.outDir = outDir.toUri

    //get extConfigs
    os := Env.cur.os
    getStartsWith(os+".", props, build.extConfigs)

  }

  **
  ** mini build for boost
  **
  virtual Int main(Str[] args)
  {
    build = BuildCpp()
    scriptFile = args.last.toUri.toFile.normalize
    props := scriptFile.in.readProps
    parse(props)
    nargs := args.dup
    nargs.pop
    return build.main(nargs)
  }

  static Uri[] allDir(Uri base, Uri dir)
  {
    Uri[] subs := [,]
    (base + dir).toFile.walk |File f|
    {
      if(f.isDir)
      {
        rel := f.uri.relTo(base)
        subs.add(rel)
      }
    }
    return subs
  }

}