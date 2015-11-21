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
class CppCompiler : Task
{

  ** Output repository
  File? outHome

  ** lib name
  Str? name

  ** description of pod
  Str? summary

  ** output file name
  Str? outFileName

  ** output file pod dir
  File? outPodDir

  ** output file dir
  File? outDir

  ** lib depends
  Depend[]? depends

  ** lib depends
  Version? version

  ** Output target type
  TargetType? outType

  ** is debug mode
  Bool debug := false

  ** List of ext librarie to link in
  Str[]? libName

  ** List of macro define
  Str[]? define

  ** List of include
  File[]? includeDir

  ** List of lib dir
  File[]? libDir

  ** List of source files or directories to compile
  File[]? src
  Regex? excludeSrc := null
  File? scriptDir

  ** List of resource
  File[]? res := null

  ** Home directory for VC or GCC
  ** configured via config prop
  Str? ccHome

  ** meta data
  private [Str:Str]? meta

  ** compiler
  Str? compiler

  ** command maker
  private CommandMaker? commandMaker

  ** ctor
  new make(BuildScript script)
    : super(script)
  {}

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  **
  ** Run the cc task
  **
  override Void run()
  {
    log.info("CompileCpp")

    try
    {
      init
      objDir := (outPodDir + `obj/`).create
      srcCodes.each
      {
        echo(it.osPath)
        commandMaker.srcList = it.osPath.replace(" ", "::")
        commandMaker.outObjFile = (objDir+(it.basename).toUri).osPath.replace(" ", "::")
        commandMaker.objList.add(commandMaker.outObjFile)
        compile
      }

      if (outType == TargetType.lib)
        makeLib
      else
        link(outType == TargetType.dll)
      install
    }
    catch (Err err)
    {
      throw fatal("CompileCpp failed")
    }
  }

  ** init. since dump test
  protected virtual Void init()
  {
    outFileName = name
    outPodDir = outHome + ("$name-$version/").toUri
    outPodDir.create

    Uri dir := (outType == TargetType.exe) ? `bin/` : `lib/`
    outDir = (outPodDir + dir).create

    meta =
    [
      "pod.name" : name,
      "pod.version" : version.toStr,
      "pod.depends" : depends.map { it.toStr } ->join(";"),
      "pod.summary" : summary,
    ]

    commandMaker = CommandMaker
    {
      it.libName = allLibs
      it.define = this.define
      it.includeDir = allIncludes.map { it.osPath.replace(" ", "::") }
      it.libDir = allLibPaths.map { it.osPath.replace(" ", "::") }
      it.outFile = (outDir +outFileName.toUri).osPath.replace(" ", "::")
      it.outLibFile = (outDir +("lib"+outFileName).toUri).osPath.replace(" ", "::")
      //it.objList = objFiles.map { it.osPath.replace(" ", "::") }
      it.config = this.typeof.pod.props(`config.props`, 1min).dup
    }
  }

  private Void exeCmd(Str cmd)
  {
    cmds := cmd.split.map { it.replace("::", " ") }
    try {
      Exec(script, cmds).run
    } catch (Err err) {
      echo((cmds.map |Str s->Str| { s.contains(" ") ? "\"$s\"" : s }).join(" "))
      throw err
    }
  }

  ** compile the source code
  protected virtual Void compile()
  {
    cmd := ccHome.replace(" ", "::") + commandMaker.getCommond(compiler + ".comp")
    exeCmd(cmd)
  }

  ** link target to exe or dll
  protected virtual Void link(Bool isDll)
  {
    cmd := ccHome.replace(" ", "::") + commandMaker.getCommond(compiler + (isDll ? ".dll" : ".exe"))
    exeCmd(cmd)
  }

  ** make a lib file
  protected virtual Void makeLib()
  {
    cmd := ccHome.replace(" ", "::") + commandMaker.getCommond(compiler + ".lib")
    exeCmd(cmd)
  }

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////


  protected File[] srcCodes()
  {
      File[] srcs := [,]
      src.each |File f|
      {
        if (f.isDir){
          f.listFiles.each {
            ext := it.ext
            if (ext == "cpp" || ext == "c" || ext == "cc" || ext == "cxx") {
              if (excludeSrc != null)
              {
                if (!excludeSrc.matches(it.name))
                {
                  srcs.add(it)
                }
              }
              else
              {
                srcs.add(it)
              }
            }
          }
        }else{
          srcs.add(f)
        }
      }
      return srcs
  }

  protected File[] allIncludes()
  {
      File[] incs := [,]
      includeDir.each
      {
        incs.add(it)
      }

      src.each |File f|
      {
        if (f.isDir){
          incs.add(f)
        }
      }
      incs.add(scriptDir)

      //depends include
      depends.each
      {
        dep := outHome + `${it.name}-${it.version}/include/`
        if (!dep.exists) throw fatal("don't find the depend $it")
        incs.add(dep)
      }
      return incs
  }

//////////////////////////////////////////////////////////////////////////
// Link
//////////////////////////////////////////////////////////////////////////

  protected File[] objFiles()
  {
      File[] objs := [,]
      objDir := outPodDir + `obj/`
      objDir.listFiles.each
      {
        if (it.ext == "obj" || it.ext == "o")
        {
          objs.add(it)
        }
      }
      return objs
  }

  protected Str[] allLibs()
  {
      Str[] libNames := [,]

      //depend libs
      depends.each
      {
        dep := outHome + `${it.name}-${it.version}/lib/`
        count := 0
        dep.listFiles.each
        {
          if (it.ext == "lib" || it.ext == "a" || it.ext == "so")
          {
            if (it.name.startsWith("lib") && it.name.endsWith(".a"))
            {
              i := it.name.indexr(".a")
              libNames.add(it.name[3..<i])
            }
            else if (it.name.startsWith("lib") && it.name.endsWith(".so"))
            {
              i := it.name.indexr(".so")
              libNames.add(it.name[3..<i])
            }
            else
              libNames.add(it.name)
            count++
          }
        }
        if (count == 0)
          throw fatal("don't find any lib in ${it.name}-${it.version}/lib/")
      }

      //user libs
      libName.each
      {
        libNames.add(it)
      }
      return libNames
  }

  protected File[] allLibPaths()
  {
      //depend libs path
      depends.each
      {
        dep := outHome + `${it.name}-${it.version}/lib/`
        libDir.add(dep)
      }
      return libDir
  }

//////////////////////////////////////////////////////////////////////////
// install
//////////////////////////////////////////////////////////////////////////

  **
  ** copy include head and res
  **
  Void install()
  {
    if (res != null)
    {
      copyInto(res, outDir, false, ["overwrite":true])
    }

    if (outType != TargetType.exe)
    {
      //copy include files
      includeDir := (outPodDir + `include/$name/`).create
      copyInto(src, includeDir, true,
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

    log.info("outFile: " + (outDir + outFileName.toUri).osPath)
  }

  private Void copyInto(File[] src, File dir, Bool flatten, [Str:Obj]? options := null)
  {
    src.each |File f|
    {
      if (f.isDir && flatten)
      {
        f.listFiles.each
        {
          it.copyInto(dir, options)
        }
      }else{
        f.copyInto(dir, options)
      }
    }
  }

}