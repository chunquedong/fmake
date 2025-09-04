
## Overview

声明式 C++ 构建工具

### Features

- 声明式的配置构建脚本
- 跨平台，支持gcc、msvc、emscripten等编译器
- 生成 Visual Studio、 XCode 项目文件
- 依赖管理库


### Install

需要现安装 [Fanx runtime](https://github.com/fanx-dev/fanx/blob/master/doc/QuickStart.md).

从源码构建:
```
  fanb pod.props
```

### 从shell使用微软C++工具集:
```
source vsvars.sh
```
[详细信息参见这里](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-170)

### 用法

#### 编译

构建脚本 'fmake.props':
```
  name = helloExe
  summary = test exe
  version = 1.0.1
  outType = exe
  srcDirs = cpp/
  incDir = include/
  depends = helloLib 1.0.0, abc 1.2
```
编译:
```
  fan fmake fmake.props
```
debug模式编译:
```
  fan fmake -d fmake.props
```
清理后重新编译:
```
  fan fmake -f fmake.props
```
指定编译器:
```
  fan fmake fmake.props -c gcc
```

#### 生成IDE项目文件
需要安装cmake.
```
  fan fmake -G -debug fmake.props
```

#### 构建脚本细节

```
  name: 库名称
  summary: 描述
  version: 构建版本
  outType: exe, lib, dll
  srcDirs: 输入的源文件路径（文件夹需要以'/'结尾）
  excludeSrc: 在搜索源文件时需要排除的文件
  incDirs: 需要拷贝的头文件目录
  resDirs: 需要拷贝的资源文件目录
  depends: 依赖的库（只需要名称和版本号，不需要指定头文件和库文件）
  extIncDirs: 额外的头文件搜索路径
  extLibDirs: 额外的库文件搜索路径
  extLibs: 额外依赖的库名称
  defines: 用户定义的宏
  extConfigs.cppflags: 编译器选项
  incDst: 头文件安装位置
  extConfigs.linkflags: 连接器选项
  debug.defines： debug模式的定义
  debug.extLibs： debug模式的额外库名称
```

#### 编译器和平台相关配置
可以前缀操作系统名称
- win32
- macosx
- linux
- non-win
例如：
```
win32.extIncDirs = ...
linux.define = ...
```

可以前缀编译器名称
```
gcc.define = ...
msvc.define = ...
```

### 配置
创建配置文件fanx/env/etc/fmake/config.props

可以用来重写config.props中的配置, 例如:
```
emcc.home=C:/soft/emsdk/upstream/emscripten/
```

### 包仓库

包仓库是个固定结构的文件夹，没有网络操作。

目录结构
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



### 做更多的任务

请编写shell脚本来做，不要在makefile里面写业务逻辑。跨平台编译优先使用编程语言“宏”功能来处理。
