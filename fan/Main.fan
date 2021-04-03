//
// Copyright (c) 2021, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2021-4-3  Jed Young  Creation
//

class Main
{

  BuildCpp? build

  private File? scriptFile

//////////////////////////////////////////////////////////////////////////

  private Uri[]? parseDirs(Str? str, Uri[]? defV := null) {
    if (str == null) return defV
    srcDirs := Uri[,]
    str.split(',').each |d| {
      if (d.endsWith("*")) {
        srcUri := d[0..<-1].toUri
        dirs := allDir(scriptFile.uri, srcUri)
        srcDirs.addAll(dirs)
      }
      else {
        srcDirs.add(d.toUri)
      }
    }
    return srcDirs
  }

  private Void getStartsWith(Str str, [Str:Str] props, [Str:Str] map) {
    props.each |v,k| {
      if (k.startsWith(str)) {
        k = k[str.size..-1]
        map[k] = v
      }
    }
  }

  private Void parse(Str os, [Str:Str] props) {
    build->scriptFile = scriptFile

    name := props.get(os+"name")
    if (name != null) build.name = name
    summary := props.get(os+"summary")
    if (summary != null) build.summary = summary

    versionStr := props.get(os+"version")
    if (versionStr != null) build.version = Version(versionStr)

    //get depends
    props.get(os+"depends", "").split(',').each { if (it.size>0) build.depends.add(it) }

    //get srcDirs
    build.srcDirs.addAll(parseDirs(props.get(os+"srcDirs"), [,]))

    includeDir := props.get(os+"incDir")
    if (includeDir != null) build.incDir = includeDir.toUri

    //get resDirs    
    resDirs := parseDirs(props.get(os+"resDirs"))
    if (resDirs != null) {
      if (build.resDirs == null) build.resDirs = [,]
      build.resDirs.addAll(resDirs)
    }

    excludeSrc := props.get(os+"excludeSrc")
    if (excludeSrc != null) build.excludeSrc = Regex.fromStr(excludeSrc)

    outType := props.get(os+"outType")
    if (outType != null) build.outType = TargetType.fromStr(outType)

    debug := props.get(os+"debug")
    if (debug != null) build.debug = "debug"

    build.extLibs.addAll(props.get(os+"extLibs", "").split(','))
    build.defines.addAll(props.get(os+"defines", "").split(','))

    build.extIncDirs.addAll(parseDirs(props.get(os+"extIncDirs"), [,]))
    build.extLibDirs.addAll(parseDirs(props.get(os+"extLibDirs"), [,]))

    //get outPodDir
    outDir := props.get(os+"outDir", null)
    if (outDir != null) build.outDir = outDir.toUri

    //get extConfigs
    getStartsWith(os+"extConfigs", props, build.extConfigs)
  }

  **
  ** mini build for boost
  **
  Int run(Str[] args)
  {
    build = BuildCpp()
    Str[]? nargs
    arg := args.first
    if (arg == null || !arg.endsWith(".props")) {
      arg = "fmake.props"
      nargs = args
    }
    else {
      nargs = args[1..-1]
    }

    scriptFile = arg.toUri.toFile.normalize
    props := scriptFile.in.readProps
    parse("", props)
    parse(Env.cur.os+".", props)

    return build.main(nargs)
  }

  static Int main() {
    return Main().run(Env.cur.args)
  }

  static Uri[] allDir(Uri base, Uri dir)
  {
    Uri[] subs := [,]
    (base + dir).toFile.walk |File f|
    {
      if(f.isDir)
      {
        rel := f.uri.relTo(base)
        subs.add(rel)
      }
    }
    return subs
  }

}