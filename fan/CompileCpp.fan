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
    compiler = buildInfo.compiler
    compHome = config(compiler+".home", "")
    outPodDir = (buildInfo.outDir + ("$buildInfo.name/").toUri).toFile
    objDir = File(buildInfo.scriptDir+`../build/obj-$buildInfo.name-$compiler-$buildInfo.debug/`).create
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

  private File getObjFile(Uri srcFile) {
    pathStr := srcFile.pathStr
    objName := pathStr.replace(buildInfo.scriptDir.pathStr, "")
    if (objName != pathStr) {
      objName = objName.replace("..", "_");
    }
    else {
      ps := srcFile.path;
      if (ps.size == 1) {
        objName = ps[0]
      }
      else if (ps.size > 1) {
        objName = ps[-2]+"/"+ps[-1]
      }
      else {
        objName = pathStr
      }
    }
    objFile := objDir+(objName+".o").toUri
    return objFile;
  }

  **
  ** Run the cc task
  **
  Void run()
  {
    log.info("Compile module: ${buildInfo.name} compiler: $compiler")

    try {
      init
    } catch (Err e) {
      echo(configs)
      throw fatal("CompileCpp init failed", e)
    }

    try {
      buildInfo.sources.each |srcFile| {
        //echo("touch $srcFile")
        configs["srcFile"] = fileToStr(srcFile.toFile)
        objFile := getObjFile(srcFile)
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
        exeCmd("lib")
      else
        exeCmd(buildInfo.outType == TargetType.dll ? "dll" : "exe")

      install

      log.info("BUILD SUCCESS")

      if (buildInfo.execute && (buildInfo.outType == TargetType.exe)) {
        exeBin
      }
    } catch (Err e) {
      log.info(e.msg)
      e.trace
      log.info("BUILD FAIL")
    }
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
    if (buildInfo.outType != TargetType.exe) {
      outPodDir.delete
    }
    objDir.delete
  }

  Void fixWin32([Str:Str] configs, Str key, Str value) {
    v := configs[key]
    if (v == null) return
    if (v.contains(".bat")) return
    v = v.replace(value, value+".bat")
    configs[key] = v;
  }

  ** init. since dump test
  protected Void init()
  {
    outPodDir.create

    Uri dir := (buildInfo.outType == TargetType.exe) ? `bin/` : `lib/`
    outBinDir = (outPodDir + dir).create
    outFile = (outBinDir + buildInfo.name.toUri)
    outLibFile := (outBinDir +("lib"+buildInfo.name).toUri)

    
    meta =
    [
      "pod.name" : buildInfo.name,
      "pod.version" : buildInfo.version.toStr,
      "pod.depends" : buildInfo.depends.map { it.toStr } ->join(";"),
      "pod.summary" : buildInfo.summary,
      "pod.buildTime" : DateTime.now.toStr,
      "pod.compiler" : compiler
    ]

    if (buildInfo.includeDst == null) {
      includes := [,]
      for (i:=0; i<buildInfo.installHeaders.size; ++i) {
        includeDir := buildInfo.installHeaders[i]
        if (includeDir.isDir) {
          includes.add(includeDir.pathStr)
        }
      }
      if (includes.size > 0) {
        meta["pod.includes"] = includes.join(",")
      }
      meta["pod.includesRewrite"] = (includes.size == buildInfo.installHeaders.size).toStr
    }

    configs = this.typeof.pod.props(`config.props`, 1min).dup
    //temp fix emcc
    if (Env.cur.os == "win32") {
      fixWin32(configs, "emcc.ar", "emar")
      fixWin32(configs, "emcc.name@{cpp}", "emcc")
      fixWin32(configs, "emcc.name@{c}", "emcc")
      fixWin32(configs, "emcc.link", "emcc")
    }
    configs["outFile"] = fileToStr(outFile)
    configs["outLibFile"] = fileToStr(outLibFile)
    configs["cflags"] = ""
    configs["cppflags"] = ""
    configs["linkflags"] = ""
    configs.setAll(buildInfo.extConfigs)

    params := [Str:Str[]][:]
    params["libNames"] = buildInfo.libs
    params["defines"] = buildInfo.defines
    params["incDirs"] = buildInfo.incDirs.map { fileToStr(it.toFile) }
    params["libDirs"] = buildInfo.libDirs.map { fileToStr(it.toFile) }

    scriptPath := buildInfo.scriptDir.pathStr
    curDir := File.os(".").normalize.uri
    params["objList"] = buildInfo.sources.map |f| {
      objFile := getObjFile(f)
      //echo("###$curDir,$objFile")
      objFile = (objFile.uri.relTo(curDir)).toFile
      return fileToStr(objFile)
    }


    applayMacrosForList(params)
    selectMacros(buildInfo.debug)
    fileDirtyMap.clear

    oldFile := outBinDir +("lib"+buildInfo.name+".a").toUri
    oldFile.delete
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
        --i
      }
    }
    return s
  }

  private Void exeCmd(Str name)
  {
    cmd := configs[compiler+"."+name]
    cmd = applyMacros(cmd, configs)
    cmd = compHome.replace(" ", "::") + cmd

    cmds := cmd.split.map { it.replace("::", " ") }
    
    process := Process(cmds)
    inc := config("${compiler}.include_dir")
    lib := config("${compiler}.lib_dir")
    if (inc != null)
      process.env["INCLUDE"] = inc.split(';').map{it.toUri.toFile.osPath}.join(";")
    if (lib != null)
      process.env["LIB"] = lib.split(';').map{it.toUri.toFile.osPath}.join(";")
    
    log.info("Exec $cmd")
    result := process.run.join
    if (result != 0) throw fatal("Exec failed [$cmd]")

  }

  private Void exeBin() {
    Process([outFile.osPath]).run.join
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
        depend = depend.normalize
        //echo("isDirty:$depend")
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

  private Void copyHeaderFile(File? outDir) {
    File? dstIncludeDir
    if (buildInfo.includeDst != null) {
      dstIncludeDir = (outDir + `include/${buildInfo.includeDst}/`).create
    }
    else {
      dstIncludeDir = (outDir + `include/`).create
    }

    copyInto(buildInfo.installHeaders, dstIncludeDir, true,
    [
      "overwrite":true,
      "exclude":|File f->Bool|
      {
        if (f.isDir) return false
        return f.ext != "h" && f.ext != "hpp" && f.ext != "inl"
      }
    ])
  }

  **
  ** copy include head and res
  **
  Void install()
  {
    if (buildInfo.resDirs.size > 0) {
      copyInto(buildInfo.resDirs, outPodDir, false, ["overwrite":true])
    }

    if (buildInfo.outType != TargetType.exe) {
      copyHeaderFile(outPodDir)

      if (buildInfo.installGlobal) {
        copyHeaderFile(buildInfo.outDir.toFile)

        libDirs := (buildInfo.outDir + `lib/`).toFile.create
        (outPodDir+`lib/`).copyTo(libDirs, ["overwrite":true])
      }
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