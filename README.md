
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
./vsvars.sh
```
You might need to eidt the path in the vsvars.sh file.
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
```

Compiler name
```
gcc.define = ...
msvc.define = ...
```


### Package Repository

```
fmakeRepo
   |_msvc
      |_emcc
      |_msvc
      |_gcc
        |_pro1-1.0-debug
        |  |_bin
        |  |_include
        |  |_obj
        |  |_lib
        |_pro2-1.0-debug
        |  |_bin
        |  |_include
        |  |_obj
        |  |_lib
        |...

```


### Do More Task

Please write shell script.
