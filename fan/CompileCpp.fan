//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-3  Jed Young  Creation
//

using build

**
** Run the Cpp compiler
**
class CompileCpp : Task
{

  ** Output repository
  File outHome

  ** lib name
  Str name

  ** description of pod
  Str summary

  ** output file name
  private File? outFile

  ** output file pod dir
  private File? outPodDir

  ** output file dir
  private File? outDir

  private File? objDir

  ** lib depends
  Depend[] depends

  ** lib depends
  Version version

  ** Output target type
  TargetType outType

  ** is debug mode
  Str debug

  ** List of ext librarie to link in
  Str[] extLibs

  ** List of macro define
  Str[] defines

  ** List of include
  File[] extIncDirs

  ** List of lib dir
  File[] extLibDirs

  ** List of source files or directories to compile
  File[] srcDirs
  Regex? excludeSrc := null

  File? includeDir

  File? scriptDir

  ** List of resource
  File[]? resDirs := null

  ** Home directory for VC or GCC
  ** configured via config prop
  Str compHome

  ** meta data
  private [Str:Str]? meta

  ** compiler
  Str compiler

  Str:Str extConfigs

  private [Str:Str]? configs

  private [File:Bool] fileDirtyMap := [:]

  ** ctor
  new make(BuildScript script, |This| f)
    : super(script)
  {
    f(this)
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  **
  ** Run the cc task
  **
  override Void run()
  {
    log.info("CompileCpp")

    try {
      init
    } catch (Err e) {
      echo(configs)
      throw fatal("CompileCpp init failed", e)
    }

    srcList.each |srcFile| {
      //echo("touch $srcFile")
      configs["srcFile"] = fileToStr(srcFile)
      objName := srcFile.pathStr.replace(scriptDir.pathStr, "")
      objFile := objDir+(objName+".o").toUri
      if (objFile.exists && !objFile.isDir) {
        if (!isDirty(srcFile, objFile.modified - 1sec)) {
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

    if (outType == TargetType.lib)
      exeCmd("lib", objDir)
    else
      exeCmd(outType == TargetType.dll ? "dll" : "exe", objDir)

    install
  }

  static Str fileToStr(File f) {
    f.osPath.replace(" ", "::")
  }

  ** init. since dump test
  protected Void init()
  {
    outPodDir = outHome + ("$name-$version-$debug/").toUri
    outPodDir.create

    Uri dir := (outType == TargetType.exe) ? `bin/` : `lib/`
    outDir = (outPodDir + dir).create
    outFile = (outDir + name.toUri)
    outLibFile := (outDir +("lib"+name).toUri)
    objDir = (outPodDir + `obj/`).create

    meta =
    [
      "pod.name" : name,
      "pod.version" : version.toStr,
      "pod.depends" : depends.map { it.toStr } ->join(";"),
      "pod.summary" : summary,
      "pod.buildTime" : DateTime.now.toStr,
      "pod.compiler" : compiler
    ]

    configs = this.typeof.pod.props(`config.props`, 1min).dup
    configs["outFile"] = fileToStr(outFile)
    configs["outLibFile"] = fileToStr(outLibFile)
    configs["cflags"] = ""
    configs["cppflags"] = ""
    configs.setAll(extConfigs)

    params := [Str:Str[]][:]
    params["libNames"] = libNames
    params["defines"] = defines
    params["incDirs"] = incDirs.map { fileToStr(it) }
    params["libDirs"] = libDirs.map { fileToStr(it) }

    scriptPath := scriptDir.pathStr
    params["objList"] = srcList.map |f| {
      path := f.pathStr.replace(scriptPath, "")
      return fileToStr((path+".o").toUri.toFile)
    }

    applayMacrosForList(params)
    selectMacros(debug)
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

  private Void exeCmd(Str name, File? dir := null)
  {
    cmd := configs[compiler+"."+name]
    cmd = script.applyMacros(cmd, configs)
    cmd = compHome.replace(" ", "::") + cmd

    cmds := cmd.split.map { it.replace("::", " ") }
    try {
      e := Exec(script, cmds, dir)
      inc := script.config("env.include")
      lib := script.config("env.lib")
      if (inc != null)
        e.process.env["INCLUDE"] = inc.split(';').map{it.toUri.toFile.osPath}.join(";")
      if (lib != null)
        e.process.env["LIB"] = lib.split(';').map{it.toUri.toFile.osPath}.join(";")
      e.run
    } catch (Err err) {
      throw fatal(cmds.join(" "), err)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  protected once File[] srcList()
  {
      File[] srcs := [,]
      srcDirs.each |File f| {
        if (f.isDir){
          f.listFiles.each {
            ext := it.ext
            if (ext == "cpp" || ext == "c" || ext == "cc" || ext == "cxx") {
              if (excludeSrc != null) {
                if (!excludeSrc.matches(it.name)) {
                  srcs.add(it)
                }
              }
              else {
                srcs.add(it)
              }
            }
          }
        } else {
          srcs.add(f)
        }
      }
      return srcs
  }

  protected once File[] incDirs()
  {
      File[] incs := extIncDirs.dup
      /*
      srcDirs.each |File f| {
        if (f.isDir) {
          incs.add(f)
        }
      }*/
      incs.add(scriptDir)

      //depends include
      depends.each
      {
        dep := outHome + `${it.name}-${it.version}-${debug}/include/`
        if (!dep.exists) throw fatal("don't find the depend $it")
        incs.add(dep)
      }
      return incs
  }

  private File? searchHeaderFile(File self, Str name) {
    f := self.parent + name.toUri
    if (f.exists && !f.isDir) return f

    return incDirs.eachWhile |p| {
      f = p + name.toUri
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
// Link
//////////////////////////////////////////////////////////////////////////

  protected once Str[] libNames()
  {
      Str[] libs := [,]

      //depend libs
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
          throw fatal("don't find any lib in ${it.name}-${it.version}/lib/")
      }

      //user libs
      extLibs.each
      {
        libs.add(it)
      }
      return libs
  }

  protected once File[] libDirs()
  {
      //depend libs path
      list := extLibDirs.dup
      depends.each {
        dep := outHome + `${it.name}-${it.version}-${debug}/lib/`
        list.add(dep)
      }
      return list
  }

//////////////////////////////////////////////////////////////////////////
// install
//////////////////////////////////////////////////////////////////////////

  **
  ** copy include head and res
  **
  Void install()
  {
    if (resDirs != null) {
      copyInto(resDirs, outDir, false, ["overwrite":true])
    }

    if (outType != TargetType.exe) {
      //copy include files
      dstIncludeDir := (outPodDir + `include/`).create
      copyInto([this.includeDir], dstIncludeDir, true,
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

  private Void copyInto(File[] src, File dir, Bool flatten, [Str:Obj]? options := null)
  {
    src.each |File f|
    {
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