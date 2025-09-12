//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-2  Jed Young  Creation
//

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

class BuildCpp
{
  ** lib name
  Str? name

  ** description of pod
  Str? summary

  ** output file dir
  Uri? outDir

  ** lib depends
  Depend[] depends := [,]

  ** lib depends
  Version version := Version("1.0")

  ** Output target type
  TargetType? outType

  ** is debug mode
  Str debug = "release"

  ** List of ext librarie to link in
  Str[] libs := [,]

  ** List of macro define
  Str[] defines := [,]

  ** List of include
  Uri[] incDirs := [,]

  ** List of lib dir
  Uri[] libDirs := [,]

  ** List of source files or directories to compile
  Uri[] sources := [,]

  ** make file location
  Uri? scriptDir

  ** self public include to install
  Uri[] installHeaders = [,]

  ** header file install destination directories
  Str? includeDst

  ** List of resource
  Uri[] resDirs := [,]

  ** ext compiler options
  Str:Str extConfigs := [:]

  ** exclude src file by regex
  Str? excludeSrc

  ** src directories
  Uri[] srcDirs := [,]

  Bool installGlobal = false

  Log log := Log.get("fmake")

  ** compiler name
  Str? compiler

  Bool execute = false

//////////////////////////////////////////////////////////////////////////
// parse
//////////////////////////////////////////////////////////////////////////

  private Void validate()
  {
    if (name == null) throw fatal("Must set name")
    if (outType == null) throw fatal("Must set outType")
    if (summary == null) throw fatal("Must set summary")
  }

  private Uri[] srcList(Uri[] srcDirs, Regex? excludeSrc)
  {
      Uri[] srcs := [,]
      srcDirs.each |path| {
        File f := path.toFile
        if (f.isDir){
          f.listFiles.each {
            ext := it.ext
            if (ext == "cpp" || ext == "c" || ext == "cc" || ext == "cxx" || ext == "m" || ext == "C" || ext == "c++") {
              if (excludeSrc != null) {
                rel := it.uri.relTo(scriptDir)
                if (!excludeSrc.matches(rel.toStr)) {
                  srcs.add(it.uri)
                }
              }
              else {
                srcs.add(it.uri)
              }
            }
          }
        } else {
          srcs.add(f.uri)
        }
      }
      return srcs
  }

  static Uri[] allDirs(Uri scriptDir, Uri dir)
  {
    Uri base := scriptDir
    Uri[] subs := [,]
    (base + dir).toFile.walk |File f|
    {
      if(f.isDir)
      {
        //rel := f.uri.relTo(base)
        subs.add(f.uri)
      }
    }
    return subs
  }

  private Uri[]? parseDirs(Str? str, Uri[]? defV := null) {
    if (str == null) return defV
    srcDirs := Uri[,]
    str.split(',').each |d| {
      if (d.endsWith("*")) {
        srcUri := d[0..<-1].toUri
        dirs := allDirs(scriptDir, srcUri)
        srcDirs.addAll(dirs)
      }
      else {
        uri := scriptDir + d.toUri
        if (d == "./") {
          uri = scriptDir
        }
        if (!uri.toFile.exists) throw fatal("Invalid file: $uri")
        srcDirs.add(uri)
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

  private Void osParse(Str os, [Str:Str] props) {
    build := this
    name := props.get(os+"name")
    if (name != null) build.name = name
    summary := props.get(os+"summary")
    if (summary != null) build.summary = summary

    versionStr := props.get(os+"version")
    if (versionStr != null) build.version = Version(versionStr)

    //get depends
    props.get(os+"depends", "").split(',').each {
      if (it.size>0) build.depends.add(Depend(it))
    }

    //get srcDirs
    srcDirs := parseDirs(props.get(os+"srcDirs"), [,])
    excludeSrc := props.get(os+"excludeSrc")
    if (excludeSrc != null) {
      build.excludeSrc = excludeSrc
    }
    build.srcDirs.addAll(srcDirs)

    includeDir := props.get(os+"incDir")
    if (includeDir != null) {
      incDir := scriptDir+includeDir.toUri
      build.installHeaders.add(incDir)
      if (incDir.isDir) { build.incDirs.add(incDir) }
    }
    
    incDirs := parseDirs(props.get(os+"incDirs"))
    if (incDirs != null) {
      build.installHeaders.addAll(incDirs)
      incDirs.each |incdir| {
        if (incdir.isDir) build.incDirs.add(incdir)
      }
    }

    includeDst := props.get(os+"incDst")
    if (includeDst != null) {
      build.includeDst = includeDst
    }
    //get resDirs
    resDirs := parseDirs(props.get(os+"resDirs"))
    if (resDirs != null) build.resDirs.addAll(resDirs)

    outType := props.get(os+"outType")
    if (outType != null) build.outType = TargetType.fromStr(outType)

    extLibs := props.get(os+"extLibs")
    if (extLibs != null) build.libs.addAll(extLibs.split(','))
    debugExtLibs := props.get(os+debug +".extLibs")
    if (debugExtLibs != null) build.libs.addAll(debugExtLibs.split(','))

    defines := props.get(os+"defines")
    if (defines != null) build.defines.addAll(defines.split(','))
    debugDefines := props.get(os+debug +".defines")
    if (debugDefines != null) build.defines.addAll(debugDefines.split(','))

    build.incDirs.addAll(parseDirs(props.get(os+"extIncDirs"), [,]))
    build.libDirs.addAll(parseDirs(props.get(os+"extLibDirs"), [,]))

    //get outPodDir
    outDir := props.get(os+"outDir", null)
    if (outDir != null) {
      build.outDir = outDir.toUri.toFile.normalize.uri
    }
    //get extConfigs
    getStartsWith(os+"extConfigs.", props, build.extConfigs)
  }

  ** init devHomeDir
  private static File getFmakeRepoDir() {
    devHome := Env.cur.vars["FMAKE_REPO"]
    if (devHome != null) {
      //Windows driver name
      if (devHome.size > 1 && devHome[0].isAlpha && devHome[1] == ':') {
        devHome = File.os(devHome).uri.toStr
      }
    }
    if (devHome == null)
      devHome = Main#.pod.config("fmakeRepo")

    if (devHome == null) {
      devHome = Env.cur.userDir.toStr + "/fmakeRepo/"
    }

    if (devHome != null)
    {
      path := devHome.toUri
      f := File(path)
      if (!f.exists) {
        f.create
      }
      else if (!f.isDir) throw Err("Invalid dir URI for '$devHome'")
      return f
    }
    else {
      return Env.cur.workDir + `fmakeRepo/`
    }
  }

  Void applayDepends(Bool checkError) {
      outHome := outDir.toFile
      depends.each
      {
        includesRewrite := false
        metaPath := outHome + `${it.name}/meta.props`
        if (metaPath.exists) {
          meta := metaPath.in.readProps
          rversion := Version(meta.get("pod.version"))
          if (!it.match(rversion)) {
            fatal("Cannot resolve depend: '$it.name $rversion' != '$it'")
          }
          includesRewrite = meta.get("pod.includesRewrite") == "true"
          includes := meta.get("pod.includes")
          if (includes != null) {
            includes.split(',').each |include| {
              includePath := Uri(include).toFile
              if (includePath.exists) {
                incDirs.add(includePath.uri)
              }
              else {
                includesRewrite = false
              }
            }
          }
        }
        if (!includesRewrite) {
          dep := outHome + `${it.name}/include/`
          if (!dep.exists) {
            if (checkError) {
              throw fatal("don't find the depend $it")
            }
            else {
              fatal("don't find the depend $it")
            }
          }
          incDirs.add(dep.uri)
        }

        dep := outHome + `${it.name}/lib/`
        if (!dep.exists) {
          if (checkError) {
            throw fatal("don't find the depend $it")
          }
          else {
            fatal("don't find the depend $it")
          }
        }
        libDirs.add(dep.uri)
      }

      depends.each
      {
        dep := outHome + `${it.name}/lib/`
        count := 0
        dep.listFiles.each
        {
          if (it.ext == "a" || it.ext == "so")
          {
            if (it.name.startsWith("lib") && it.name.endsWith(".a"))
            {
              i := it.name.indexr(".a")
              libs.add(it.name[3..<i])
            }
            else if (it.name.startsWith("lib") && it.name.endsWith(".so"))
            {
              i := it.name.indexr(".so")
              libs.add(it.name[3..<i])
            }
            else {
              libs.add(it.name)
            }
            count++
          }
        }
        if (count == 0) {
          dep.listFiles.each
          {
            if (it.ext == "lib")
            {
              libs.add(it.name)
              count++
            }
          }
        }
        if (count == 0) {
          if (checkError) {
            throw fatal("don't find any lib in $dep")
          }
          else {
            fatal("don't find any lib in $dep")
          }
        }
      }
  }

  Void parse(Uri scriptFile, Bool checkError) {
    log.info("Input $scriptFile")
    scriptDir = scriptFile.parent
    props := scriptFile.toFile.in.readProps
    osParse("", props)
    if (Env.cur.os != "win32") {
      osParse("non-win", props)
    }
    osParse(Env.cur.os+".", props)

    if (compiler == null) {
      compiler = props.get("compiler")
      if (compiler == null) {
        compiler = Env.cur.config(this.typeof.pod, "compiler", null)
        if (compiler == null) {
          compiler = Env.cur.os == "win32" ? "msvc" : "gcc"
        }
      }
    }
    osParse(compiler+".", props)

    osParse(Env.cur.os+"-"+compiler+".", props)

    installGlobal = Env.cur.config(this.typeof.pod, "installGlobal", "false") == "true"

    excludeRegex := excludeSrc == null ? null : Regex.fromStr(excludeSrc)
    this.sources.addAll(srcList(this.srcDirs, excludeRegex))

    if (outDir == null) {
      outDirFile := (getFmakeRepoDir + `$compiler/${debug}/`)
      outDirFile.create
      outDir = outDirFile.uri
    }

    applayDepends(checkError)
    libs.reverse
    validate
  }

  **
  ** Log an error and return a FatalBuildErr instance
  **
  Err fatal(Str msg, Err? err := null)
  {
    log.err(msg, err)
    return Err(msg, err)
  }

  Void dump() {
    this.typeof.fields.each |f| {
      echo(f.name+"\t"+f.get(this))
    }
  }

}

