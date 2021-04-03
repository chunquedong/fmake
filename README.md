
## Overview

Declarative C++ build tool

### Install

It's depends [Fanx runtime](https://github.com/fanx-dev/fanx/blob/master/doc/QuickStart.md).

Build from source:
```
  fan build.fan
```

### Setting

1. Setting compiler
fanx/etc/fmake/config.props:
```
  compiler=msvc
```
2. Add Env vars
```
  INCLUDE=D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/
  LIB=D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/lib/x64/;C:/Program Files (x86)/Windows Kits/10/Lib/10.0.18362.0/ucrt/x64/;C:/Program Files (x86)/Windows Kits/10/
  path=D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/bin/Hostx64/x64
```

### Usage

build script 'fmake.props':
```
  name = helloExe
  summary = test exe
  outType = exe
  srcDirs = cpp/
  incDir = cpp/
  depends = helloLib 1.0.0
  debug = true
```
compile:
``
  fan fmake -f
``

generate project
```
  fan fmake -G
```

### Package Repository

The defalut output to 'fanx/lib/cpp/'
```
  fanxHome
   |_lib
      |_java
      |_donet
      |_fan
      |_cpp
        |_pro1
        |  |_bin
        |  |_include
        |  |_obj
        |  |_lib
        |_pro2
        |  |_bin
        |  |_include
        |  |_obj
        |  |_lib
        |...

````
