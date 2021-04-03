

class Generator {
	private BuildCpp buildInfo
	private File file
	private Log log := Log.get("fmake")

	new make(BuildCpp buildInfo) {
		this.buildInfo = buildInfo
		outDir := (buildInfo.scriptDir + `build/`).toFile
		outDir.create
		file = outDir + `CMakeLists.txt`
	}

	Void run() {
		out := file.out
		gen(out)
		out.close
		exe
	}

	private Void exe() {
		cmds := ["cmake", "."]
		try {
		  dir := buildInfo.scriptDir + `build/`
	      process := Process(cmds, dir.toFile)
	      log.info("Exec $cmds")
	      result := process.run.join
	      if (result != 0) throw Err("Exec failed [$cmds]")
	    } catch (Err err) {
	      throw Err("Exec failed [$cmds]")
	    }
	}

	private Str toPath(Uri uri) {
		"\""+uri.toFile.osPath.replace("\\", "/")+"\""
	}

	private Void gen(OutStream out) {
		out.printLine("cmake_minimum_required (VERSION 2.8)")
		out.printLine("project ($buildInfo.name)")


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
		out.printLine(")")


		out.printLine("target_link_libraries ($buildInfo.name ")
    	buildInfo.libs.each {
    		out.print("  $it\n")
    	}
		out.printLine(")")
	}
}