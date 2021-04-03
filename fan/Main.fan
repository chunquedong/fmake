//
// Copyright (c) 2021, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2021-4-3  Jed Young  Creation
//

class Main
{
  static Int main() {
    Str[] args = Env.cur.args
    Str[]? nargs
    arg := args.first

    if (arg == null || !arg.endsWith(".props")) {
      arg = "fmake.props"
      nargs = args
    }
    else {
      nargs = args[1..-1]
    }

    scriptFile := arg.toUri.toFile.normalize.uri
    build := BuildCpp()
    build.parse(scriptFile)

    if (nargs.first == "-G") {
      Generator(build).run
    }
    else if (nargs.first == "-dump") {
      build.dump
    }
    else {
      cc := CompileCpp(build)
      if (nargs.first == "-f") {
        cc.clean
      }
      cc.run
    }

    return 0
  }
}