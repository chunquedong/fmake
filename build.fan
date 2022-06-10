#! /usr/bin/env fan
//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-3  Jed Young  Creation
//

using build

class Build : BuildPod
{
  new make()
  {
    podName = "fmake"
    summary = "A Fantom style C++ build tool"
    depends =
    [
        "sys 2.0", "std 1.0"
    ]
    srcDirs = [`fan/`]
    resDirs = [`config.props`]
  }
}