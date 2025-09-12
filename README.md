
## Overview

Declarative C++ build tool

### Features

- Declarative make file script
- Cross-platform and support gcc, msvc, emscripten
- Generate Visual Studio and XCode project file
- Dependency Package Management


### Install

It depends on [Fanx runtime](https://github.com/fanx-dev/fanx/blob/master/doc/QuickStart.md).

Build from source:
```
  fanb pod.props
```

### Use the Microsoft C++ toolset from the shell:
```
source vsvars.sh
```
[See also](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-170)

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
  fan fmake -d fmake.props
```
clean and compile:
```
  fan fmake -f fmake.props
```
special compiler:
```
  fan fmake fmake.props -c gcc
```

#### Generate project files
require install cmake.
```
  fan fmake -G -debug fmake.props
```

#### Build script detail

```
  name: name of lib
  summary: discription
  version: build version
  outType: exe, lib, dll
  srcDirs: input directory or file (Must ends with '/' for dir)
  excludeSrc: exclude regex in srcDirs scan
  incDirs: include directory to copy
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
win32-gcc.extLibs = ...
```

Compiler name
```
gcc.define = ...
msvc.define = ...
```

### Configuration
Create the configuration file: fanx/env/etc/fmake/config.props

You can rewrite config.props to customize configurations, for example:
```
emcc.home=C:/soft/emsdk/upstream/emscripten/
```

### Package Repository

```
fmakeRepo
   |_msvc
      |_emcc
      |_msvc
      |_gcc
        |_debug
        |  |_pro1
        |    |_bin
        |    |_include
        |    |_lib
        |_release
        |  |_pro1
        |    |_bin
        |    |_include
        |    |_lib
```


### Do More Task

Please write shell script.
