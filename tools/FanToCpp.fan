#! /usr/bin/env fan
//
// Copyright (c) 2009-2012, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2012-01-19  Jed Young  Creation
//

using util

**
** Convert Fantom code to C++
**
class FanToCpp : AbstractMain
{

  @Arg { help = "pod name to generate" }
  Str? podName

  @Opt { help = "namespace"; aliases = ["n"] }
  Str? namespace

  @Opt { help = "dir"; aliases = ["d"] }
  Str? dir

  @Opt { help = "copy right"; aliases = ["c"] }
  Str copyRight := "Copyright (c) 2009-2012, chunquedong"

  CcWriter out := CcWriter(Env.cur.out)
  CcWriter impOut := CcWriter(Env.cur.out)
  CcWriter headOut := CcWriter(Env.cur.out)

  override Int run()
  {
    pod := Pod.find(podName)

    //head file
    File headOutFile := File(`gen/${dir ?: podName}/${dir ?: podName}.h`)
    headOut = CcWriter(headOutFile.out)
    Str ns := namespace ?: podName
    Str headGuard := "_"+ ns.upper +"_"+ (dir ?: podName).upper + "_H_"
    printHeadComment(headOut)
    headOut.pl("#ifndef $headGuard")
    headOut.pl("#define $headGuard").nl
    headOut.pl(Str<|#include "fanSys/Sys.h"|>)
    headOut.pl("#define ${ns.upper}_EXPORT")
    headOut.pl("namespace ${ns}")
    headOut.pl("{").indent

    pod.types.each |type|
    {
      if (!type.isSynthetic)
      {
        File outFile := File(`gen/${dir ?: podName}/${type.name}.h`)
        out = CcWriter(outFile.out)
        File impOutFile := File(`gen/${dir ?: podName}/${type.name}.cpp`)
        impOut = CcWriter(impOutFile.out)

        printType(type)
        headOut.pl("class $type.name;")
      }
    }
    out.out.close
    impOut.out.close

    headOut.unindent.pl("}") //end namespace

    pod.types.each |type|
    {
      if (!type.isSynthetic)
      {
        headOut.pl("typedef ${ns}::$type.name ${ns.upper}${type.name};")
      }
    }

    headOut.w("#endif").nl
    headOut.out.close
    return 0
  }

  private Void printDoc(CcWriter out, Str? doc)
  {
    out.pl(Str<|/**|>)
    doc?.splitLines?.each |line|
    {

      out.pl(" * "+line)
    }
    out.pl(Str<| */|>)
  }

  private Void printHeadComment(CcWriter out)
  {
     out.w(
     """//
        // $copyRight
        //
        // History:
        //   $Date.today auto-generated
        //

        """
    )
  }

  private Void printMethod(CcWriter out, Method method, Bool isImp)
  {
    if (isImp)
    {
      if (method.isAbstract) return
      if (method.isPrivate) printDoc(out, method.doc)
    }
    else
    {
      if (!method.isPrivate)
      {
        printDoc(out, method.doc)
        out.w("public: ")
      } else out.w("private: ")

      if (method.isStatic) out.w("static ")
      if (method.isVirtual) out.w("virtual ")
    }

    if (method.returns == Void#)
    {
      out.w("void ")
    }
    else
    {
      out.w(method.returns.name).w(" ")
      if (!method.returns.isVal) out.w("*")
    }
    if (isImp) out.w(method.parent.name + "::")
    out.w(method.name).w("(")

    method.params.each |param, i|
    {
      if (i > 0) out.w(", ")
      out.w(param.type.name).w(" ")
      if (!param.type.isVal) out.w("*")
      out.w(param.name)
    }

    if (isImp)
    {
      out.w(")").nl
      out.pl("{")
      out.pl("  throw new exception(\"not implemented yet\");")
      out.pl("}").nl
    }
    else
    {
      out.w(")")
      if (method.isAbstract) out.w(" = NULL")
      out.w(";").nl.nl
    }
  }

  private Void printType(Type type)
  {
    Str ns := namespace ?: type.pod.name

    //print imp
    printHeadComment(impOut)
    impOut.pl("""#include "${dir ?: podName}/${type.name}.h\"""").nl
    impOut.pl("${ns.upper}_USING_NAMESPACE").nl


    //
    Str headGuard := "_"+ ns.upper +"_"+ type.name.upper + "_H_"

    printHeadComment(out)

    out.pl("#ifndef $headGuard")
    out.pl("#define $headGuard").nl

    out.pl("""#include "${dir ?: podName}/${dir ?: podName}.h\"""").nl

    out.pl("${ns.upper}_BEGIN_NAMESPACE")
    out.pl("").indent

    printDoc(out, type.doc)

    out.w("class ${ns.upper}_EXPORT $type.name : public $type.base.name")
    type.mixins.each { out.w(", public $it.name") }
    out.nl
    out.pl("{").indent

    type.fields.each |field|
    {
      if (field.parent == type)
      {
        printDoc(out, field.doc)
        if (field.isPublic) out.w("public: ")
        else out.w("private: ")
        if (field.isStatic)
        {
          out.w("static ")
        }
        if (field.isConst) out.w("const ")
        out.w(field.type.name).w(" ")
        if(!field.type.isVal) out.w("*")
        out.w(field.name).w(";").nl.nl
      }
    }
    out.nl.pl("//=========================================================").nl
    type.methods.each |method|
    {
      if (method.parent == type && !method.isSynthetic)
      {
        printMethod(out, method, false)
        printMethod(impOut, method, true)
      }
    }

    out.unindent.pl("};") //end class

    out.unindent.pl("${ns}_END_NAMESPACE") //end namespace
    out.w("#endif").nl

  }
}


**
** CcWriter.
**
class CcWriter
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  **
  ** Make for specified output stream
  **
  new make(OutStream out)
  {
    this.out = out
  }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  **
  ** Write and then return this.
  **
  CcWriter w(Obj o)
  {
    if (needIndent)
    {
      out.writeChars(Str.spaces(indentation*2))
      needIndent = false
    }
    out.writeChars(o.toStr)
    return this
  }

  **
  ** Print Line
  **
  This pl(Obj o)
  {
    w(o).nl
  }

  **
  ** Write newline and then return this.
  **
  public CcWriter nl()
  {
    w("\n")
    needIndent = true
    out.flush
    return this
  }

  **
  ** Increment the indentation.
  **
  CcWriter indent()
  {
    indentation++
    return this
  }

  **
  ** Decrement the indentation.
  **
  CcWriter unindent()
  {
    indentation--
    if (indentation < 0) indentation = 0
    return this
  }

  This comments(Str str)
  {
    w("//" + str + "\n")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  OutStream out
  Int indentation := 0
  Bool needIndent := false

}