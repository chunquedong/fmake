//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-3  Jed Young  Creation
//

**
** Run the Cpp compiler
**
class CompileCpp
{
  ** output file name
  private File? outFile

  ** output file pod dir
  private File? outPodDir

  ** output file dir
  private File? outBinDir

  private File? objDir

  private BuildCpp buildInfo

  ** meta data
  private [Str:Str]? meta

  ** compiler name
  Str compiler

  ** compiler home
  Str compHome

  ** configs.props
  private [Str:Str]? configs

  private [File:Bool] fileDirtyMap := [:]

  private Log log := Log.get("fmake")

  ** ctor
  new make(BuildCpp buildInfo)
  {
    this.buildInfo = buildInfo
    compiler = config("compiler", Env.cur.os == "win32" ? "msvc" : "gcc" )
    compHome = config(compiler+".home", "")
    outPodDir = (buildInfo.outDir + ("$buildInfo.name-$buildInfo.version-$buildInfo.debug/").toUri).toFile
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////
  **
  ** Log an error and return a FatalBuildErr instance
  **
  Err fatal(Str msg, Err? err := null)
  {
    log.err(msg, err)
    return Err(msg, err)
  }

  **
  ** Run the cc task
  **
  Void run()
  {
    log.info("compile [${buildInfo.scriptDir.name}] $compiler")

    try {
      init
    } catch (Err e) {
      echo(configs)
      throw fatal("CompileCpp init failed", e)
    }

    buildInfo.sources.each |srcFile| {
      //echo("touch $srcFile")
      configs["srcFile"] = fileToStr(srcFile.toFile)
      objName := srcFile.pathStr.replace(buildInfo.scriptDir.pathStr, "")
      objFile := objDir+(objName+".o").toUri
      if (objFile.exists && !objFile.isDir) {
        if (!isDirty(srcFile.toFile, objFile.modified - 1sec)) {
          //echo("pass $srcFile $objFile")
          return
        }
      }
      objFile.parent.create
      configs["objFile"] = fileToStr(objFile)

      if (srcFile.ext == "c") {
        selectMacros("c")
      } else {
        selectMacros("cpp")
      }
      exeCmd("comp")
    }

    if (buildInfo.outType == TargetType.lib)
      exeCmd("lib", objDir)
    else
      exeCmd(buildInfo.outType == TargetType.dll ? "dll" : "exe", objDir)

    install

    log.info("BUILD SUCCESS")
  }

  static Str fileToStr(File f) {
    f.osPath.replace(" ", "::")
  }

  Str? config(Str name, Str? def := null)
  {
    Env.cur.vars["FAN_BUILD_$name.upper"] ?:
    Env.cur.config(this.typeof.pod, name, def)
  }

  Void clean() {
    outPodDir.delete
  }

  ** init. since dump test
  protected Void init()
  {
    outPodDir.create

    Uri dir := (buildInfo.outType == TargetType.exe) ? `bin/` : `lib/`
    outBinDir = (outPodDir + dir).create
    outFile = (outBinDir + buildInfo.name.toUri)
    outLibFile := (outBinDir +("lib"+buildInfo.name).toUri)
    objDir = (outPodDir + `obj/`).create

    meta =
    [
      "pod.name" : buildInfo.name,
      "pod.version" : buildInfo.version.toStr,
      "pod.depends" : buildInfo.depends.map { it.toStr } ->join(";"),
      "pod.summary" : buildInfo.summary,
      "pod.buildTime" : DateTime.now.toStr,
      "pod.compiler" : compiler
    ]

    configs = this.typeof.pod.props(`config.props`, 1min).dup
    configs["outFile"] = fileToStr(outFile)
    configs["outLibFile"] = fileToStr(outLibFile)
    configs["cflags"] = ""
    configs["cppflags"] = ""
    configs.setAll(buildInfo.extConfigs)

    params := [Str:Str[]][:]
    params["libNames"] = buildInfo.libs
    params["defines"] = buildInfo.defines
    params["incDirs"] = buildInfo.incDirs.map { fileToStr(it.toFile) }
    params["libDirs"] = buildInfo.libDirs.map { fileToStr(it.toFile) }

    scriptPath := buildInfo.scriptDir.pathStr
    params["objList"] = buildInfo.sources.map |f| {
      path := f.pathStr.replace(scriptPath, "")
      return fileToStr((path+".o").toUri.toFile)
    }

    applayMacrosForList(params)
    selectMacros(buildInfo.debug)
    fileDirtyMap.clear
  }

  private Str getPatternKey(Str s) {
    for (i:=0; i<s.size-3; ++i)
    {
      if (s[i] == '@' && s[i+1] == '{')
      {
        c := s.index("}", i+2)
        if (c == null) throw Err("Unclosed macro: $s")
        key := s[i+2..<c]
        return key
      }
    }
    throw Err("macro error: $s")
  }

  private Void selectMacros(Str mode) {
    configs.dup.each |v, k| {
      pos := k.index("@")
      if (pos != null && pos < k.size) {
        key := k.replace("@{$mode}", "")
        configs[key] = v
      }
    }
  }

  private Void applayMacrosForList([Str:Str[]] params) {
    configs.dup.each |v, k| {
      if (v.size> 2 && v[0] == '[' && v[v.size-1] == ']') {
        pattern := v[1..-2]
        key := getPatternKey(pattern)
        list := params[key]
        flatten := list.map { pattern.replace("@{$key}", it) }.join(" ")
        configs[k] = flatten
      }
    }
  }

    **
  ** Apply a set of macro substitutions to the given pattern.
  ** Substitution keys are indicated in the pattern using "@{key}"
  ** and replaced by definition in macros map.  If a substitution
  ** key is undefined then raise an exception.  The `configs`
  ** method is used for default macro key/value map.
  **
  Str applyMacros(Str pattern, [Str:Str] macros := this.configs)
  {
    // short circuit if we don't have @
    at := pattern.index("@")
    if (at == null) return pattern

    // rebuild string
    s := pattern
    for (i:=0; i<s.size-3; ++i)
    {
      if (s[i] == '@' && s[i+1] == '{')
      {
        c := s.index("}", i+2)
        if (c == null) throw Err("Unclosed macro: $pattern")
        key := s[i+2..<c]
        val := macros[key]
        if (val == null) throw Err("Undefined macro key: $key")
        s = s[0..<i] + val + s[c+1..-1]
      }
    }
    return s
  }

  private Void exeCmd(Str name, File? dir := null)
  {
    cmd := configs[compiler+"."+name]
    cmd = applyMacros(cmd, configs)
    cmd = compHome.replace(" ", "::") + cmd

    cmds := cmd.split.map { it.replace("::", " ") }
    try {
      process := Process(cmds, dir)
      inc := config("env.include")
      lib := config("env.lib")
      if (inc != null)
        process.env["INCLUDE"] = inc.split(';').map{it.toUri.toFile.osPath}.join(";")
      if (lib != null)
        process.env["LIB"] = lib.split(';').map{it.toUri.toFile.osPath}.join(";")
      
      log.info("Exec $cmds")
      result := process.run.join
      if (result != 0) throw fatal("Exec failed [$cmd]")
    } catch (Err err) {
      throw fatal(cmds.join(" "), err)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  private File? searchHeaderFile(File self, Str name) {
    f := self.parent + name.toUri
    if (f.exists && !f.isDir) return f

    return buildInfo.incDirs.eachWhile |p| {
      f = p.toFile + name.toUri
      if (f.exists && !f.isDir) return f
      else return null
    }
  }

  private Bool isDirty(File srcFile, TimePoint time) {
    dirty := fileDirtyMap[srcFile]
    if (dirty != null) {
      return dirty
    }

    if (srcFile.modified >= time) {
      fileDirtyMap[srcFile] = true
      //echo("$srcFile dirty")
      return true
    }
    fileDirtyMap[srcFile] = false

    Str[] lines := [,]
    try {
      lines = srcFile.readAllLines
    } catch (Err e) {
      log.warn("read file error: $srcFile")
      return true
    }

    for (i:=0; i<lines.size; ++i) {
      f := lines[i].trim
      if (!f.startsWith("#include")) {
        continue
      }
      f = f["#include".size..-1].trim
      if (f.size > 2 && f[0] == '\"' && f[f.size-1] == '\"') {
        f = f[1..-2]
        depend := searchHeaderFile(srcFile, f)
        if (depend == null) {
          log.warn("not found include file: $f, in: $srcFile")
          continue
        }
        if (isDirty(depend, time)) {
          fileDirtyMap[srcFile] = true
          return true
        } else {
          //echo("$depend ok")
        }
      }
    }
    return false
  }

//////////////////////////////////////////////////////////////////////////
// install
//////////////////////////////////////////////////////////////////////////

  **
  ** copy include head and res
  **
  Void install()
  {
    if (buildInfo.resDirs.size > 0) {
      copyInto(buildInfo.resDirs, outBinDir, false, ["overwrite":true])
    }

    if (buildInfo.outType != TargetType.exe) {
      //copy include files
      dstIncludeDir := (outPodDir + `include/`).create
      copyInto([buildInfo.includeDir], dstIncludeDir, true,
        [
          "overwrite":true,
          "exclude":|File f->Bool|
          {
            if (f.isDir) return false
            return f.ext != "h" && f.ext != "hpp"
          }
        ])
    }

    (outPodDir + `meta.props`).out.writeProps(meta)

    log.info("outFile: " + (outFile).osPath)
  }

  private static Void copyInto(Uri[] src, File dir, Bool flatten, [Str:Obj]? options := null)
  {
    src.each |uri|
    {
      f := uri.toFile
      if (f.isDir && flatten)
      {
        f.list.each
        {
          it.copyInto(dir, options)
        }
      }else{
        f.copyInto(dir, options)
      }
    }
  }

}