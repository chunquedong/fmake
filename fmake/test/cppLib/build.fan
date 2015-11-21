using fmake

class Build : BuildCpp
{
  new make()
  {
    name = "helloLib"
    summary = "test lib"
    outType = TargetType.lib
    version = Version("1.0.0")
    srcDirs = [`cpp/`]
    resDirs = [`res/`]
  }
}