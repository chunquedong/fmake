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

  @Opt { help = "execute build result file"; }
  Bool execute = false

  @Arg { help = "build script" }
  Str? scriptPath

  override Int run() {
    File scriptFile = File.os(scriptPath ?: "fmake.props")

    build := BuildCpp()
    if (debug) {
      build.debug = "debug"
    }
    if (execute) {
      build.execute = execute
    }
    if (compiler != null) {
      build.compiler = compiler
    }
    build.parse(scriptFile.normalize.uri, !generate && !dump)

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