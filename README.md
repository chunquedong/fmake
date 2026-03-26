
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
or:
```
make
```

Add bin/ to your PATH.

### Use the Microsoft C++ toolset from the shell:
```
source vsvars.sh
```
Or create the configuration file: bin/config.props：
```
msvc.home=C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/
msvc.env.incDirs=C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/include/;\
C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/ucrt/;\
C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/winrt/;\
C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/cppwinrt/winrt/;\
C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/shared/;\
C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/um/

msvc.env.libDirs=C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/lib/x64/;\
C:/Program Files (x86)/Windows Kits/10/Lib/10.0.26100.0/ucrt/x64/;\
C:/Program Files (x86)/Windows Kits/10/Lib/10.0.26100.0/um/x64/
```
[See also](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-170)

## Usage

#### Compile

build script 'fmake.props':
```
  [helloExe]
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
  name: name of lib (Not recommended)
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
  linkflags: link flags
  cppflags: compiler flags
  incDst: header file directory name
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
If a module is built with another build system, it needs to be declared in the bin/virtual_modules.ini file. For example:
```
[Qt]
incDirs = D:/Qt/6.8.0/mingw_64/include/,D:/Qt/6.8.0/mingw_64/include/QtWidgets/,D:/Qt/6.8.0/mingw_64/include/QtGui/,D:/Qt/6.8.0/mingw_64/include/QtCore/
libDirs = D:/Qt/6.8.0/mingw_64/lib/
libs = Qt6Widgets,Qt6Gui,Qt6Core
```

### Package Repository

```
fmakeRepo
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
