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
    summary = "a fantom style C++ build tool"
    depends =
    [
        "sys 1.0", "build 1.0"
    ]
    srcDirs = [`fan/`]
    resDirs = [`config.props`]
  }
}