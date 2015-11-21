using fmake

class Build : BuildCpp
{
  new make()
  {
    name = "helloExe"
    summary = "test exe"
    outType = TargetType.exe

    srcDirs = [`cpp/`]
    depends = ["helloLib 1.0.0"]
  }
}