

class Generator {
	private BuildCpp buildInfo
	private Log log := Log.get("fmake")
	private File outDir
	private Uri? fmakeRepo
	private Bool isQmake

	new make(BuildCpp buildInfo) {
		this.buildInfo = buildInfo
		outDir = (buildInfo.scriptDir + `../build/`).toFile
		outDir.create
		fmakeRepoStr := Env.cur.vars["FMAKE_REPO"]
		if (fmakeRepoStr != null) {
			fmakeRepo = File.os(fmakeRepoStr).uri
		}
	}

	Void run() {
		isQmake = true
		qout := (outDir + `${buildInfo.name}-${buildInfo.debug}.pro`).out
		genQmake(qout)
		qout.close
		echo(outDir + `${buildInfo.name}-${buildInfo.debug}.pro`)

		isQmake = false
		cmakeDir := outDir + `cmake-${buildInfo.name}-${buildInfo.debug}/`
		out := (cmakeDir+`CMakeLists.txt`).out
		genCmake(out)
		out.close
		echo(cmakeDir)
		exe(cmakeDir)
	}

	private Void exe(File cmakeDir) {
		cmds := ["cmake", "."]
		if (Env.cur.os == "win32") {
			cmds.add("-A").add("x64")
		}
		try {
	      process := Process(cmds, cmakeDir)
	      log.info("Exec $cmds")
	      result := process.run.join
	      if (result != 0) throw Err("Exec failed [$cmds]")
	    } catch (Err err) {
	      throw Err("Exec failed [$cmds]")
	    }
	}

	private Str toPath(Uri uri, Bool keepPath = false, Str? filter = null) {
		rel := uri.relTo(buildInfo.scriptDir)

		path := rel.toFile.osPath

		if (rel.pathStr != uri.pathStr) {
            parentName := buildInfo.scriptDir.name
			if (isQmake) {
				path = "../$parentName/"+path
			}
			else {
				path = "../../$parentName/"+path
			}
		}
		else if (fmakeRepo != null) {
			rel = uri.relTo(fmakeRepo)
			if (rel != uri) {
				if (isQmake) {
					path = "\$\$(FMAKE_REPO)/"+rel.toFile.osPath
				}
				else {
					path = "\$ENV{FMAKE_REPO}/"+rel.toFile.osPath
				}
			}
		}

		if (filter != null) {
			path += "/" + filter
		}

		if (Env.cur.os == "win32") {
			if (!keepPath) {
				path = path.replace("\\", "/")
			}
			else {
				path = path.replace("/", "\\")
			}
		}

		if (path.contains(" ")) {
			path = "\""+path+"\""
		}
		return path
	}

	private Void genCmake(OutStream out) {
		out.printLine("cmake_minimum_required (VERSION 3.0)")
		out.printLine("project (${buildInfo.name}_ws)")

		cflags := buildInfo.extConfigs["cflags"]
		cppflags := buildInfo.extConfigs["cppflags"]

		if (cflags != null) {
			out.printLine("list(APPEND CMAKE_C_FLAGS $cflags)")
		}
		if (cppflags != null) {
			out.printLine("list(APPEND CMAKE_CXX_FLAGS $cppflags)")
		}

		if (buildInfo.debug == "debug") {
			out.printLine("SET(CMAKE_BUILD_TYPE \"Debug\")")
		}

		out.printLine("add_definitions (")
		buildInfo.defines.each {
			out.print("  -D$it\n")
		}
		out.printLine(")")


		out.printLine("include_directories (")
		buildInfo.incDirs.each {
			out.print("  ${toPath(it)}\n")
		}
		out.printLine(")")


		out.printLine("link_directories (")
		buildInfo.libDirs.each {
			out.print("  ${toPath(it)}\n")
		}
		out.printLine(")")


		if (buildInfo.outType == TargetType.exe) {
			out.printLine("add_executable ($buildInfo.name ")
		}
		else if (buildInfo.outType == TargetType.lib) {
	    	out.printLine("add_library ($buildInfo.name STATIC ")
	    }
	    else if (buildInfo.outType == TargetType.dll) {
	    	out.printLine("add_library ($buildInfo.name SHARED ")
	    }
	    buildInfo.sources.each {
			out.print("  ${toPath(it)}\n")
		}

		buildInfo.installHeaders.each |incdir| {
			incdir.toFile.walk |f| {
				if (f.ext == "h" || f.ext == "hpp" || f.ext == "inl") {
					out.print("  ${toPath(f.uri)}\n")
				}
			}
		}
		out.printLine(")")


		out.printLine("target_link_libraries ($buildInfo.name ")
    	buildInfo.libs.each {
    		out.print("  $it\n")
    	}
		out.printLine(")")


		//set lib output dir
		outPodDir := (buildInfo.outDir + ("$buildInfo.name-$buildInfo.version/").toUri)
		out.printLine("set_target_properties ($buildInfo.name PROPERTIES ")
		Str? libOut
		if (buildInfo.outType == TargetType.exe) {
			libOut = toPath(outPodDir+`bin/`)
		}
		else {
			libOut = toPath(outPodDir+`lib/`)
		}
		out.printLine("  ARCHIVE_OUTPUT_DIRECTORY $libOut")
		out.printLine("  LIBRARY_OUTPUT_DIRECTORY $libOut")
		out.printLine("  RUNTIME_OUTPUT_DIRECTORY $libOut")
		out.printLine("  ARCHIVE_OUTPUT_DIRECTORY_DEBUG $libOut")
		out.printLine("  LIBRARY_OUTPUT_DIRECTORY_DEBUG $libOut")
		out.printLine("  RUNTIME_OUTPUT_DIRECTORY_DEBUG $libOut")
		out.printLine("  ARCHIVE_OUTPUT_DIRECTORY_RELEASE $libOut")
		out.printLine("  LIBRARY_OUTPUT_DIRECTORY_RELEASE $libOut")
		out.printLine("  RUNTIME_OUTPUT_DIRECTORY_RELEASE $libOut")
		out.printLine(")")

		//copy res
		buildInfo.resDirs.each {
			out.printLine("add_custom_command(TARGET $buildInfo.name POST_BUILD ")
	        out.printLine("  COMMAND \${CMAKE_COMMAND} -E copy_directory ")
	        resOut := toPath(outPodDir+`res/`)
	        out.printLine("  ${toPath(it)} $resOut ")
	        out.printLine(")")
	    }

	    //copy include
	    if (buildInfo.outType != TargetType.exe) {
	    	copyHeaderFile |from, to| {
        		incFrom := toPath(from)
        		incOut := toPath(outPodDir+to)

			    out.printLine("add_custom_command(TARGET $buildInfo.name POST_BUILD ")
		        out.printLine("  COMMAND \${CMAKE_COMMAND} -E copy ")
		        out.printLine("  $incFrom $incOut ")
		        out.printLine(")")
	        }
	    }
	}

	private Void copyHeaderFile(|Uri,Uri| cb) {
		buildInfo.installHeaders.each |incdir| {
			incdir.toFile.walk |f| {
				if (f.ext == "h" || f.ext == "hpp" || f.ext == "inl") {
					rel := f.uri.relTo(incdir)
					Uri? dstIncludeDir
					if (buildInfo.includeDst != null) {
						dstIncludeDir = (`include/${buildInfo.includeDst}/$rel`)
					}
					else {
						dstIncludeDir = (`include/$rel`)
					}
					cb.call(f.uri, dstIncludeDir)
				}
			}
		}
	}

	private Void genQmake(OutStream out) {
		out.printLine("#QT -= core gui")
		out.printLine("TARGET = $buildInfo.name")
		if (buildInfo.outType == TargetType.exe) {
			out.printLine("TEMPLATE = app")
		}
		else if (buildInfo.outType == TargetType.lib) {
	    	out.printLine("TEMPLATE = lib")
	    	out.printLine("CONFIG   += staticlib")
	    }
	    else if (buildInfo.outType == TargetType.dll) {
	    	out.printLine("TEMPLATE = lib")
	    }


		cflags := buildInfo.extConfigs["cflags"]
		cppflags := buildInfo.extConfigs["cppflags"]

		if (cflags != null) {
			out.printLine("QMAKE_CC += $cflags")
		}
		if (cppflags != null) {
			out.printLine("QMAKE_CXXFLAGS += $cppflags")
		}

		buildInfo.defines.each {
			out.printLine("DEFINES += ${it}")
		}

		out.printLine("SOURCES += \\")
		buildInfo.sources.each {
			out.print("  ${toPath(it)} \\\n")
		}
		out.printLine("")

		out.printLine("HEADERS += \\")
		buildInfo.installHeaders.each |incdir| {
			incdir.toFile.walk |f| {
				if (f.ext == "h" || f.ext == "hpp" || f.ext == "inl") {
					out.print("  ${toPath(f.uri)} \\\n")
				}
			}
		}
		out.printLine("")

		out.printLine("INCLUDEPATH += \\")
		buildInfo.incDirs.each {
			out.print("  ${toPath(it)} \\\n")
		}
		out.printLine("")


		buildInfo.libDirs.each {
			out.print("LIBS += -L${toPath(it)}\n")
		}

		buildInfo.libs.each |name| {
			i := name.indexr(".lib")
            if (i>0) name = name[0..<i]
    		out.print("LIBS += -l$name\n")
    	}


		outPodDir := (buildInfo.outDir + ("$buildInfo.name-$buildInfo.version/").toUri)
		Str? libOut
		if (buildInfo.outType == TargetType.exe) {
			libOut = toPath(outPodDir+`bin/`)
		}
		else {
			libOut = toPath(outPodDir+`lib/`)
		}
		out.printLine("DESTDIR = $libOut")


		//copy res
		buildInfo.resDirs.each {
			resFrom := toPath(it, true)
	        resOut := toPath(outPodDir+`res/`, true)
	        out.printLine("QMAKE_POST_LINK += \$\$QMAKE_COPY_DIR $resFrom $resOut \$\$escape_expand(\\n\\t)")
	    }

	    //copy include
	    if (buildInfo.outType != TargetType.exe) {
	    	Uri? dstIncludeDir
	        if (buildInfo.includeDst != null) {
	          dstIncludeDir = (`include/${buildInfo.includeDst}/`)
	        }
	        else {
	          dstIncludeDir = (`include/`)
	        }

			buildInfo.installHeaders.each |incdir| {
				incOut := toPath(outPodDir+dstIncludeDir, true)
				if (incdir.isDir) {
					incFrom := toPath(incdir, true, "*.h")
					out.printLine("QMAKE_POST_LINK += \$\$QMAKE_COPY_DIR $incFrom $incOut \$\$escape_expand(\\n\\t)")

					incFrom = toPath(incdir, true, "*.hpp")
					out.printLine("QMAKE_POST_LINK += \$\$QMAKE_COPY_DIR $incFrom $incOut \$\$escape_expand(\\n\\t)")

					incFrom = toPath(incdir, true, "*.inl")
					out.printLine("QMAKE_POST_LINK += \$\$QMAKE_COPY_DIR $incFrom $incOut \$\$escape_expand(\\n\\t)")
				}
				else {
					incFrom := toPath(incdir, true)
					out.printLine("QMAKE_POST_LINK += \$\$QMAKE_COPY_DIR $incFrom $incOut \$\$escape_expand(\\n\\t)")
				}
			}
	    }
	}
}