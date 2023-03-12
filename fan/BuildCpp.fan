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
  Uri? includeDir

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

  Bool installGlobal = true

  Log log := Log.get("fmake")

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
            if (ext == "cpp" || ext == "c" || ext == "cc" || ext == "cxx") {
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
      build.includeDir = scriptDir+includeDir.toUri
      build.incDirs.add(build.includeDir)
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

    installGlobal := props.get(os+"installGlobal")
    if (installGlobal != null) build.installGlobal = installGlobal == "true"

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
  private static File getDevHomeDir() {
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
      devHome = Env.cur.userDir.toStr
    }

    if (devHome != null)
    {
      path := devHome.toUri
      f := File(path)
      if (!f.exists || !f.isDir) throw Err("Invalid dir URI for '$devHome'")
      return f
    }
    else {
      return Env.cur.workDir
    }
  }

  Void applayDepends() {
      outHome := outDir.toFile
      depends.each
      {
        includeFound := false
        metaPath := outHome + `${it.name}-${it.version}-${debug}/meta.props`
        if (metaPath.exists) {
          meta := metaPath.in.readProps
          include := meta.get("pod.include")
          if (include != null) {
            includePath := Uri(include).toFile
            if (includePath.exists) {
              incDirs.add(includePath.uri)
              includeFound = true
            }
          }
        }
        if (!includeFound) {
          dep := outHome + `${it.name}-${it.version}-${debug}/include/`
          if (!dep.exists) throw fatal("don't find the depend $it")
          incDirs.add(dep.uri)
        }

        dep := outHome + `${it.name}-${it.version}-${debug}/lib/`
        if (!dep.exists) throw fatal("don't find the depend $it")
        libDirs.add(dep.uri)
      }

      depends.each
      {
        dep := outHome + `${it.name}-${it.version}-${debug}/lib/`
        count := 0
        dep.listFiles.each
        {
          if (it.ext == "lib" || it.ext == "a" || it.ext == "so")
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
            else
              libs.add(it.name)
            count++
          }
        }
        if (count == 0)
          throw fatal("don't find any lib in $dep")
      }
  }

  Void parse(Uri scriptFile) {
    scriptDir = scriptFile.parent
    props := scriptFile.toFile.in.readProps
    osParse("", props)
    if (Env.cur.os != "win32") {
      osParse("non-win", props)
    }
    osParse(Env.cur.os+".", props)

    excludeRegex := excludeSrc == null ? null : Regex.fromStr(excludeSrc)
    this.sources.addAll(srcList(this.srcDirs, excludeRegex))

    if (outDir == null) {
      outDirFile := (getDevHomeDir + `lib/cpp/`)
      outDirFile.create
      outDir = outDirFile.uri
    }

    //incDirs.add(outDir + `include/`)
    //libDirs.add(outDir + `lib-${debug}/`)

    applayDepends
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

