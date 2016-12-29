//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-2  Jed Young  Creation
//

using build

abstract class BuildCpp : BuildScript
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
  ** platform depends configs item
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
// Compile
//////////////////////////////////////////////////////////////////////////

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

    allLibDirs := this.resolveDirs(extLibDirs)
    configLibDir := this.config("libDirs")
    if (configLibDir != null) {
      allLibDirs.addAll(this.resolveDirs(configLibDir.split(';').map{it.toUri}))
    }

    allIncDirs := this.resolveDirs(extIncDirs)
    configIncDir := this.config("incDirs")
    if (configIncDir != null) {
      allIncDirs.addAll(this.resolveDirs(configIncDir.split(';').map{it.toUri}))
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
      it.srcDirs    = this.resolveDirs(this.srcDirs)
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
        it.resDirs = this.resolveDirs(this.resDirs)
      }
    }

    cc.run

    log.unindent
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
  internal File[] resolveFiles(Uri[] uris)
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
  internal File[] resolveDirs(Uri[] uris)
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