//
// Copyright (c) 2021, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2021-4-3  Jed Young  Creation
//
using util

class Main : AbstractMain
{
  @Opt { help = "force rebuild"; aliases=["f"] }
  Bool force := false

  @Opt { help = "generate project file"; aliases=["G"] }
  Bool generate := false

  @Opt { help = "dump build config"; }
  Bool dump := false

  @Opt { help = "debug build"; aliases=["d"] }
  Bool debug := false

  @Opt { help = "compiler name"; aliases=["c"] }
  Str? compiler := null

  @Arg { help = "build script" }
  File? scriptFile

  override Int run() {
    if (scriptFile == null) {
      scriptFile = File.os("fmake.props")
    }

    build := BuildCpp()
    if (debug) {
      build.debug = "debug"
    }
    if (compiler != null) {
      build.compiler = compiler
    }
    build.parse(scriptFile.normalize.uri)

    if (generate) {
      Generator(build).run
    }
    else if (dump) {
      build.dump
    }
    else {
      cc := CompileCpp(build)
      if (force) {
        cc.clean
      }
      cc.run
    }
    return 0
  }
}