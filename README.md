
## Overview

Declarative C++ build tool

### Features

- Declarative make file script
- Cross-platform and support gcc msvc
- Generate Visual Studio and XCode project file
- Dependency Package Management


### Install

It depends on [Fanx runtime](https://github.com/fanx-dev/fanx/blob/master/doc/QuickStart.md).

Build from source:
```
  fan build.fan
```

### Setting on Windows
1. Setting compiler (Options)

The msvc and gcc is default compiler.

fanx/etc/fmake/config.props:
```
  compiler=clang
```

2. Config Env Vars (Options)

If you don't want to run comand line in 'Visual Studio Developer Command Prompt'.
```
  INCLUDE=D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/
  LIB=D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/lib/x64/;C:/Program Files (x86)/Windows Kits/10/Lib/10.0.18362.0/ucrt/x64/;C:/Program Files (x86)/Windows Kits/10/
  path=D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/bin/Hostx64/x64
```

### Usage

#### compile

build script 'fmake.props':
```
  name = helloExe
  summary = test exe
  version = 1.0.1
  outType = exe
  srcDirs = cpp/
  incDir = include/
  depends = helloLib 1.0.0, abc 1.2
  debug = true
```
compile:
```
  fan fmake

```
clean and compile:
```
  fan fmake -f
```

#### generate project
require install cmake.
```
  fan fmake -G
```

#### build script detail

```
  name: name of lib
  summary: discription
  version: build version
  outType: exe, lib, dll
  srcDirs: input dir or file
  excludeSrc: exclude regex in srcDirs scan
  incDir: include dir to copy
  resDirs: resource files to copy
  depends: library with version
  extIncDirs: extra include dirs
  extLibDirs: extra library dirs
  extLibs: extra depend library name
  defines: user define macro
  debug: is debug compile mode
```

#### platform-dependent configuration
Prefix OS name
- win32
- macosx
- linux

```
win32.extIncDirs = ...
linux.define = ...
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

### Do More Task

Please write shell script or fanx script.
