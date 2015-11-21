//
// Copyright (c) 2010, chunquedong
// Licensed under the Academic Free License version 3.0
//
// History:
//   2011-4-3  Jed Young  Creation
//

using build

**
** CommandMaker
**
class CommandMaker
{
  ** List of ext librarie to link in
  Str[] libName := [,]

  ** List of macro define
  Str[] define := [,]

  ** List of include
  Str[] includeDir := [,]

  ** List of lib dir
  Str[] libDir := [,]

  ** List of source files or directories to compile
  Str srcList := ""

  ** output file
  Str outFile := ""

  ** object file
  Str outObjFile := ""

  ** out lib file path
  Str outLibFile := ""

  ** List of obj file
  Str[] objList := [,]

  ** config map
  Str:Str config


  new make(|This| f) { f(this) }


  Str getCommond(Str cmd)
  {
    [Str:Str] map := [:]
    config.each |v, k|
    {
      map[k] = fillParam(v)
      //echo("$k : ${v}")
      //echo("$k => ${map[k]}")
    }

    Str command := map[cmd]

    map.each |v, k|
    {
      command = command.replace("{$k}", v)
    }
    return command
  }

  private Str fillParam(Str cmd)
  {
    Str result := cmd
    this.typeof.fields.each |f|
    {
      if (f.parent == this.typeof)
      {
        Str name := "{$f.name}"
        if (result.contains(name))
        {
          if (f.type != Str#)
          {
            Str[] strs := f.get(this)

            temp := ""
            strs.each |item|
            {
              temp += result.replace(name, item) + " "
            }
            result = temp
          }
          else
          {
            result = result.replace(name, f.get(this).toStr)
          }
        }
      }
    }

    return result
  }
}