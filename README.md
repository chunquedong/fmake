
## Overview

Declarative C++ build tool

### Features

- Declarative build script, configuring what to do rather than how to do it.
- Cross-platform and support gcc, msvc, emscripten
- Generate Visual Studio and XCode project file
- Dependency Package Management


### Install


Build from source:
```
  sh build.sh
```

Add bin/ to your PATH.

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
  fmake fmake.props
```
debug compile:
```
  fmake -d fmake.props
```
clean and compile:
```
  fmake -f fmake.props
```
special compiler:
```
  fmake fmake.props -c gcc
```

#### Generate project files
require install cmake.
```
  fmake -G -debug fmake.props
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
  extIncDirs: extra include dirs (Not recommended)
  extLibDirs: extra library dirs (Not recommended)
  extLibs: extra depend library name (Not recommended)
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
Create the configuration file: bin/config.props

You can rewrite config.props to customize configurations, for example:
```
emcc.home=C:/soft/emsdk/upstream/emscripten/
```

### Virtual Module
Modules that are depended on via depends must also be built with fmake.
If a module is built with another build system, it needs to be declared in the bin/$name.vm file. For example, Qt.vm:
```
incDirs = ...
libDirs = ...
libs = ...
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
