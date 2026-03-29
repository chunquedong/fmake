
## Fmake

声明式 C++ 构建工具

## 特性

- 声明式构建脚本，配置做什么而不是怎么做
- 跨平台，支持gcc、msvc、emscripten等编译器
- 生成 Visual Studio、 XCode 项目文件
- 内建支持依赖包管理系统
- 增量编译，只编译修改过的文件


## 安装

从源码构建(Windows平台使用git bash运行):
```
  sh build.sh
```
或者:
```
make
```
添加bin/目录到你的环境变量PATH

### 从shell使用微软C++工具集
每次启动git bash都需要运行:
```
source vsvars.sh
```
或者在bin/config.props内配置：
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
[详细信息参见这里](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-170)

## 用法

### 编译

构建脚本 'fmake.props':
```
  [helloExe]
  summary = test exe
  version = 1.0.1
  outType = exe
  srcDirs = cpp/
  incDir = include/
  depends = helloLib 1.0.0, abc 1.2
```
编译:
```
  fmake fmake.props
```
debug模式编译:
```
  fmake -d fmake.props
```
清理后重新编译:
```
  fmake -f fmake.props
```
指定编译器:
```
  fmake fmake.props -c gcc
```

### 源码路径
在fmake中srcDirs可以配置源码文件夹，或者当个文件。当配置源码文件后，会自动搜索当前文件夹下的所有源码文件。
我们约定路径使用'/'，即便在Windows上。文件夹使用'/'结尾。例如:
```
srcDirs = cpp/
```

如果像递归搜索子文件夹，需要加'*'来表示:
```
srcDirs = cpp/*
```

可以通过excludeSrc在搜索源码文件时用正则表达式过滤:
```
srcDirs = cpp/
excludeSrc = .*(cocoa|posix_).*
```

### 生成IDE项目文件
需要安装cmake.
```
  fmake -G -debug fmake.props
```

### 构建脚本细节

```
  name: 库名称（不推荐使用）
  summary: 描述
  version: 构建版本
  outType: exe, lib, dll
  srcDirs: 输入的源文件路径（文件夹需要以'/'结尾）
  excludeSrc: 在搜索源文件时需要排除的文件
  incDirs: 需要拷贝的头文件目录
  resDirs: 需要拷贝的资源文件目录
  depends: 依赖的库（只需要名称和版本号，不需要指定头文件和库文件）
  extIncDirs: 额外的头文件搜索路径（不推荐使用）
  extLibDirs: 额外的库文件搜索路径（不推荐使用）
  extLibs: 额外依赖的库名称（不推荐使用）
  defines: 用户定义的宏
  cppflags: 编译器选项
  linkflags: 连接器选项
  incDst: 头文件安装文件夹名称
  debug.defines： debug模式的定义
  debug.extLibs： debug模式的额外库名称
```

### 编译器和平台相关配置
可以前缀操作系统名称
- win32
- macosx
- linux
- non-win
例如：
```
win32.extIncDirs = ...
linux.define = ...
win32-gcc.extLibs = ...
```

可以前缀编译器名称
```
gcc.define = ...
msvc.define = ...
```

### 配置
创建配置文件bin/config.props

可以用来重写config.props中的配置, 例如:
```
emcc.home=C:/soft/emsdk/upstream/emscripten/
```

### 虚拟模块
通过depends依赖的模块需要也是fmake构建的。如果是其他构建系统构建的模块，需要在bin/virtual_modules.ini文件中声明。例如:
```
[Qt]
incDirs = D:/Qt/6.8.0/mingw_64/include/,D:/Qt/6.8.0/mingw_64/include/QtWidgets/,D:/Qt/6.8.0/mingw_64/include/QtGui/,D:/Qt/6.8.0/mingw_64/include/QtCore/
libDirs = D:/Qt/6.8.0/mingw_64/lib/
libs = Qt6Widgets,Qt6Gui,Qt6Core
```

### 包仓库

包仓库是个固定结构的文件夹，没有网络操作。

目录结构
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



### 做更多的任务

fmake不提供构建以外的功能，不能写业务逻辑，需要与shell脚本配合完成任务。
例如想做编译前下载东西，在shell脚本中这样写:
```
wget https://example.com/file.zip
fmake fmame.props
```
