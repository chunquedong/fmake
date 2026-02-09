#include "Generator.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <cstdlib>
#include "Utils.h"

Generator::Generator(const BuildCpp& buildInfo) : buildInfo(buildInfo) {
    outDir = buildInfo.scriptDir / "../build/";
    fs::create_directories(outDir);

    const char* fmakeRepo = std::getenv("FMAKE_REPO");
    if (fmakeRepo) {
        fmakeRepoLib = fs::path(fmakeRepo) / buildInfo.compiler / buildInfo.debug;
    }
}

void Generator::run(bool clean) {
    // Generate QMake file
    isQmake = true;
    fs::path qmakeFile = outDir / (buildInfo.name + "-" + buildInfo.debug + ".pro");
    std::ofstream qout(qmakeFile);
    relativePathBase = outDir;
    genQmake(qout);
    qout.close();
    std::cout << "Generate QMake file: " << qmakeFile.generic_string() << std::endl;

    // Generate CMake file
    isQmake = false;
    fs::path cmakeDir = outDir / ("cmake-" + buildInfo.name + "-" + buildInfo.debug);
    if (clean) {
        if (fs::exists(cmakeDir)) {
            fs::remove_all(cmakeDir);
        }
    }
    fs::create_directories(cmakeDir);
    fs::path cmakeFile = cmakeDir / "CMakeLists.txt";
    std::ofstream out(cmakeFile);
    relativePathBase = cmakeDir;
    genCmake(out);
    out.close();
    std::cout << "Generate CMake file: " << cmakeDir.generic_string() << std::endl;

    // Execute CMake
    exe(cmakeDir);
}

void Generator::exe(const fs::path& cmakeDir) {
    std::vector<std::string> cmds = {"cmake", "."};

    try {
        std::string cmdStr;
        for (const auto& cmd : cmds) {
            cmdStr += cmd + " ";
        }
        std::cout << "Exec " << cmdStr << " in " << cmakeDir.generic_string() << std::endl;

        // Save current directory
        fs::path oldPath = fs::current_path();
        // Change to cmakeDir
        fs::current_path(cmakeDir);
        
        int result = std::system(cmdStr.c_str());
        if (result != 0) {
            std::cerr << "Exec failed [" << cmdStr << "]" << std::endl;
        }
        
        // Restore old directory
        fs::current_path(oldPath);
    } catch (...) {
        std::cerr << "Exec failed [cmake .]" << std::endl;
    }
}

std::string Generator::toPath(const fs::path& uri, bool keepPath, const std::string* filter) const {
    std::string path;
    if (!fmakeRepoLib.empty() && uri.generic_string().find(fmakeRepoLib.generic_string()) == 0) {
        fs::path rel = fs::relative(uri, fmakeRepoLib);
        if (rel.generic_string() != uri.generic_string()) {
            if (isQmake) {
                path = "$$(FMAKE_REPO_LIB)/" + rel.generic_string();
            }
            else {
                path = "${FMAKE_REPO_LIB}/" + rel.generic_string();
            }
        }
    }
    
    if (path.empty()) {
        fs::path rel = fs::relative(uri, relativePathBase);
        if (rel.empty()) {
            rel = "./";
        }
        path = rel.generic_string();
    }

    if (filter) {
        path += "/" + *filter;
    }

    // Always use forward slashes for cross-platform compatibility
    //path = Utils::replaceAll(path, "\\", "/");

    if (path.find(' ') != std::string::npos) {
        path = "\"" + path + "\"";
    }

    return path;
}

void Generator::genQmake(std::ofstream& out) {
    out << "#QT -= core gui" << std::endl;
    out << "TARGET = " << buildInfo.name << std::endl;

    if (buildInfo.outType == TargetType::exe) {
        out << "TEMPLATE = app" << std::endl;
    } else if (buildInfo.outType == TargetType::lib) {
        out << "TEMPLATE = lib" << std::endl;
        out << "CONFIG   += staticlib" << std::endl;
    } else if (buildInfo.outType == TargetType::dll) {
        out << "TEMPLATE = lib" << std::endl;
    }

    out << "!isEmpty($$(FMAKE_REPO)) {" << std::endl;
    out << "  FMAKE_REPO_LIB = $$(FMAKE_REPO)/" << buildInfo.compiler << "/" << buildInfo.debug << std::endl;
    out << "} else {" << std::endl;
    std::string defaultRepoLib = buildInfo.outDir.generic_string();
    // Always use forward slashes for cross-platform compatibility
    defaultRepoLib = Utils::replaceAll(defaultRepoLib, "\\", "/");
    out << "  FMAKE_REPO_LIB = \"" << defaultRepoLib << "\"" << std::endl;
    out << "}" << std::endl;

    // Add cflags and cppflags
    std::string cflags;
    std::string cppflags;
    for (const auto& [k, v] : buildInfo.extConfigs) {
        if (k == "cflags") {
            cflags = v;
        } else if (k == "cppflags") {
            cppflags = v;
        }
    }

    if (!cflags.empty()) {
        out << "QMAKE_CC += " << cflags << std::endl;
    }
    if (!cppflags.empty()) {
        out << "QMAKE_CXXFLAGS += " << cppflags << std::endl;
    }

    // Add defines
    for (const auto& define : buildInfo.defines) {
        out << "DEFINES += " << define << std::endl;
    }

    // Add sources
    out << "SOURCES += \\" << std::endl;
    for (const auto& src : buildInfo.sources) {
        out << "  " << toPath(src) << " \\" << std::endl;
    }
    out << "" << std::endl;

    // Add headers
    out << "HEADERS += \\" << std::endl;
    for (const auto& incdir : buildInfo.installHeaders) {
        if (fs::is_directory(incdir)) {
            for (const auto& entry : fs::recursive_directory_iterator(incdir)) {
                if (fs::is_regular_file(entry)) {
                    std::string ext = entry.path().extension().generic_string();
                    if (ext == ".h" || ext == ".hpp" || ext == ".inl") {
                        out << "  " << toPath(entry.path()) << " \\" << std::endl;
                    }
                }
            }
        }
    }
    out << "" << std::endl;

    // Add include paths
    out << "INCLUDEPATH += \\" << std::endl;
    for (const auto& dir : buildInfo.incDirs) {
        out << "  " << toPath(dir) << " \\" << std::endl;
    }
    out << "" << std::endl;

    // Add lib directories
    for (const auto& dir : buildInfo.libDirs) {
        out << "LIBS += -L" << toPath(dir) << std::endl;
    }

    // Add libs
    for (const auto& name : buildInfo.libs) {
        std::string libName = name;
        size_t apos = libName.rfind(".lib");
        if (apos != std::string::npos) {
            libName = libName.substr(0, apos);
        }
        out << "LIBS += -l" << libName << std::endl;
    }

    // Set output directory
    fs::path outPodDir = buildInfo.outDir / buildInfo.name;
    std::string libOut;
    if (buildInfo.outType == TargetType::exe) {
        libOut = toPath(outPodDir / "bin/");
    } else {
        libOut = toPath(outPodDir / "lib/");
    }
    out << "DESTDIR = " << libOut << std::endl;

    // Copy resources
    for (const auto& resDir : buildInfo.resDirs) {
        std::string resFrom = toPath(resDir);
        std::string resOut = toPath(outPodDir / "res/");
        out << "QMAKE_POST_LINK += $$QMAKE_COPY_DIR " << resFrom << " " << resOut << " $$escape_expand(\\n\\t)" << std::endl;
    }

    // Copy includes
    if (buildInfo.outType != TargetType::exe) {
        fs::path dstIncludeDir;
        if (!buildInfo.includeDst.empty()) {
            dstIncludeDir = fs::path("include/") / buildInfo.includeDst;
        } else {
            dstIncludeDir = "include/";
        }

        for (const auto& incdir : buildInfo.installHeaders) {
            std::string incOut = toPath(outPodDir / dstIncludeDir, true);
            if (fs::is_directory(incdir)) {
                std::string incFrom = toPath(incdir, true) + "/*.h";
                out << "QMAKE_POST_LINK += $$QMAKE_COPY_DIR " << incFrom << " " << incOut << " $$escape_expand(\\n\\t)" << std::endl;

                incFrom = toPath(incdir, true) + "/*.hpp";
                out << "QMAKE_POST_LINK += $$QMAKE_COPY_DIR " << incFrom << " " << incOut << " $$escape_expand(\\n\\t)" << std::endl;

                incFrom = toPath(incdir, true) + "/*.inl";
                out << "QMAKE_POST_LINK += $$QMAKE_COPY_DIR " << incFrom << " " << incOut << " $$escape_expand(\\n\\t)" << std::endl;
            } else {
                std::string incFrom = toPath(incdir, true);
                out << "QMAKE_POST_LINK += $$QMAKE_COPY_DIR " << incFrom << " " << incOut << " $$escape_expand(\\n\\t)" << std::endl;
            }
        }
    }
}

void Generator::genCmake(std::ofstream& out) {
    out << "cmake_minimum_required (VERSION 3.10)" << std::endl;
    out << "project (" << buildInfo.name << "_ws)" << std::endl;
    out << std::endl;

    out << "if(DEFINED ENV{FMAKE_REPO})" << std::endl;
    out << "  set(FMAKE_REPO_LIB \"$ENV{FMAKE_REPO}/" << buildInfo.compiler << "/" << buildInfo.debug << "\")" << std::endl;
    out << "else()" << std::endl;
    std::string defaultRepoLib = buildInfo.outDir.generic_string();
    // Always use forward slashes for cross-platform compatibility
    defaultRepoLib = Utils::replaceAll(defaultRepoLib, "\\", "/");
    out << "  set(FMAKE_REPO_LIB \"" << defaultRepoLib << "\")" << std::endl;
    out << "endif()" << std::endl;
    out << std::endl;

    // Add cflags and cppflags
    std::string cflags;
    std::string cppflags;
    for (const auto& [k, v] : buildInfo.extConfigs) {
        if (k == "cflags") {
            cflags = v;
        } else if (k == "cppflags") {
            cppflags = v;
        }
    }

    if (!cflags.empty()) {
        out << "set(CMAKE_C_FLAGS \"${CMAKE_C_FLAGS} " << cflags << "\")" << std::endl;
    }
    if (!cppflags.empty()) {
        out << "set(CMAKE_CXX_FLAGS \"${CMAKE_CXX_FLAGS} " << cppflags << "\")" << std::endl;
    }

    if (buildInfo.debug == "debug") {
        out << "SET(CMAKE_BUILD_TYPE \"Debug\")" << std::endl;
    }

    // Add defines
    out << "add_definitions (" << std::endl;
    for (const auto& define : buildInfo.defines) {
        out << "  -D" << define << std::endl;
    }

    if (buildInfo.debug == "debug") {
        out << "  -D" << "_DEBUG" << std::endl;
    }
    else {
        out << "  -D" << "NDEBUG" << std::endl;
    }

    out << ")" << std::endl;
    out << std::endl;

    // Add include directories
    out << "include_directories (" << std::endl;
    for (const auto& dir : buildInfo.incDirs) {
        out << "  " << toPath(dir) << std::endl;
    }
    out << ")" << std::endl;
    out << std::endl;

    // Add lib directories
    out << "link_directories (" << std::endl;
    for (const auto& dir : buildInfo.libDirs) {
        out << "  " << toPath(dir) << std::endl;
    }
    out << ")" << std::endl;
    out << std::endl;

    // Add target
    if (buildInfo.outType == TargetType::exe) {
        out << "add_executable (" << buildInfo.name << " " << std::endl;
    } else if (buildInfo.outType == TargetType::lib) {
        out << "add_library (" << buildInfo.name << " STATIC " << std::endl;
    } else if (buildInfo.outType == TargetType::dll) {
        out << "add_library (" << buildInfo.name << " SHARED " << std::endl;
    }

    // Add sources
    for (const auto& src : buildInfo.sources) {
        out << "  " << toPath(src) << std::endl;
    }

    // Add headers
    for (const auto& incdir : buildInfo.installHeaders) {
        if (fs::is_directory(incdir)) {
            for (const auto& entry : fs::recursive_directory_iterator(incdir)) {
                if (fs::is_regular_file(entry)) {
                    std::string ext = entry.path().extension().generic_string();
                    if (ext == ".h" || ext == ".hpp" || ext == ".inl") {
                        out << "  " << toPath(entry.path()) << std::endl;
                    }
                }
            }
        }
    }
    out << ")" << std::endl;
    out << std::endl;

    // Add libraries
    out << "target_link_libraries (" << buildInfo.name << " " << std::endl;
    for (const auto& lib : buildInfo.libs) {
        out << "  " << lib << std::endl;
    }
    out << ")" << std::endl;
    out << std::endl;

    // Set output directories
    fs::path outPodDir = buildInfo.outDir / buildInfo.name;
    std::string libOut;
    if (buildInfo.outType == TargetType::exe) {
        libOut = toPath(outPodDir / "bin/");
    } else {
        libOut = toPath(outPodDir / "lib/");
    }

    out << "set_target_properties (" << buildInfo.name << " PROPERTIES " << std::endl;
    out << "  ARCHIVE_OUTPUT_DIRECTORY " << libOut << std::endl;
    out << "  LIBRARY_OUTPUT_DIRECTORY " << libOut << std::endl;
    out << "  RUNTIME_OUTPUT_DIRECTORY " << libOut << std::endl;
    out << "  ARCHIVE_OUTPUT_DIRECTORY_DEBUG " << libOut << std::endl;
    out << "  LIBRARY_OUTPUT_DIRECTORY_DEBUG " << libOut << std::endl;
    out << "  RUNTIME_OUTPUT_DIRECTORY_DEBUG " << libOut << std::endl;
    out << "  ARCHIVE_OUTPUT_DIRECTORY_RELEASE " << libOut << std::endl;
    out << "  LIBRARY_OUTPUT_DIRECTORY_RELEASE " << libOut << std::endl;
    out << "  RUNTIME_OUTPUT_DIRECTORY_RELEASE " << libOut << std::endl;
    out << ")" << std::endl;
    out << std::endl;

    // Copy resources
    for (const auto& resDir : buildInfo.resDirs) {
        out << "add_custom_command(TARGET " << buildInfo.name << " POST_BUILD " << std::endl;
        out << "  COMMAND ${CMAKE_COMMAND} -E copy_directory " << std::endl;
        std::string resOut = toPath(outPodDir / "res/");
        out << "  " << toPath(resDir) << " " << resOut << " " << std::endl;
        out << ")" << std::endl;
    }

    // Copy includes
    if (buildInfo.outType != TargetType::exe) {
        auto copyHeaderFunc = [&](const fs::path& from, const fs::path& to) {
            std::string incFrom = toPath(from);
            std::string incOut = toPath(outPodDir / to);

            out << "add_custom_command(TARGET " << buildInfo.name << " POST_BUILD " << std::endl;
            out << "  COMMAND ${CMAKE_COMMAND} -E copy " << std::endl;
            out << "  " << incFrom << " " << incOut << " " << std::endl;
            out << ")" << std::endl;
        };

        copyHeaderFile(copyHeaderFunc);
    }
}

void Generator::copyHeaderFile(const std::function<void(const fs::path&, const fs::path&)>& cb) {
    for (const auto& incdir : buildInfo.installHeaders) {
        if (fs::is_directory(incdir)) {
            for (const auto& entry : fs::recursive_directory_iterator(incdir)) {
                if (fs::is_regular_file(entry)) {
                    std::string ext = entry.path().extension().generic_string();
                    if (ext == ".h" || ext == ".hpp" || ext == ".inl") {
                        try {
                            fs::path rel = fs::relative(entry.path(), incdir);
                            fs::path dstIncludeDir;
                            if (!buildInfo.includeDst.empty()) {
                                dstIncludeDir = fs::path("include/") / buildInfo.includeDst / rel;
                            } else {
                                dstIncludeDir = fs::path("include/") / rel;
                            }
                            cb(entry.path(), dstIncludeDir);
                        } catch (...) {
                            // Ignore error
                        }
                    }
                }
            }
        }
    }
}
