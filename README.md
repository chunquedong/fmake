
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
  fanb pod.props
```

### Setting on Windows
1. Setting compiler (Options)
If you don't want to run in 'Visual Studio Developer Command Prompt'.
fanx/etc/fmake/config.props:
```
msvc.home=/D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/bin/Hostx64/x64/
msvc.include_dir=/D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/include/;/C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/ucrt/;/C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/winrt/;/C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/cppwinrt/winrt/;/C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/shared/;/C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/um/
msvc.lib_dir=/D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.28.29333/lib/x64/;/C:/Program Files (x86)/Windows Kits/10/Lib/10.0.18362.0/ucrt/x64/;/C:/Program Files (x86)/Windows Kits/10/Lib/10.0.18362.0/um/x64/

```

### Usage

#### Compile

build script 'fmake.props':
```
  name = helloExe
  summary = test exe
  version = 1.0.1
  outType = exe
  srcDirs = cpp/
  incDir = include/
  depends = helloLib 1.0.0, abc 1.2
```
compile:
```
  fan fmake fmake.props
```
debug compile:
```
  fan fmake -d  fmake.props
```
clean and compile:
```
  fan fmake -f  fmake.props
```
special compiler:
```
  fan fmake fmake.props -c gcc
```

#### Generate project files
require install cmake.
```
  fan fmake -G  fmake.props
```

#### Build script detail

```
  name: name of lib
  summary: discription
  version: build version
  outType: exe, lib, dll
  srcDirs: input directory or file
  excludeSrc: exclude regex in srcDirs scan
  incDir: include directory to copy
  resDirs: resource files to copy
  depends: library with version
  extIncDirs: extra include dirs
  extLibDirs: extra library dirs
  extLibs: extra depend library name
  defines: user define macro
  extConfigs.cppflags: compiler flags
  incDst: header file directory name
  extConfigs.linkflags: link flags
  debug.defines
  debug.extLibs
```

#### Compiler and Platform-dependent configuration
Prefix OS name
- win32
- macosx
- linux
- non-win

```
win32.extIncDirs = ...
linux.define = ...
```

Compiler name
```
gcc.define = ...
msvc.define = ...
```


### Package Repository

The output path setting in fanx/etc/fmake/config.props:
``
fmakeRepo=/D:/fmakeRepo/
``

```
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

```

### Emscripten

fanx/etc/fmake/config.props:
```
gcc.home=/D:/workspace/source/emsdk/upstream/emscripten/
gcc.name@{cpp}=emcc.bat @{cppflags} -pthread
gcc.name@{c}=emcc.bat @{cflags} -pthread
gcc.ar=emar.bat
gcc.link=emcc.bat -pthread
gcc.exe=@{gcc.link} @{linkflags} -o @{outFile}.js @{gcc.objList} @{gcc.libDirs} @{gcc.libNames}
```

### Do More Task

Please write shell script or fanx script.
