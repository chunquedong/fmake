#include "CompileCpp.h"
#include "Utils.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <cstdlib>
#include <chrono>
#include <algorithm>
#include <string.h>


CompileCpp::CompileCpp(const BuildCpp& buildInfo) : buildInfo(buildInfo), version(buildInfo.version) {
    compiler = buildInfo.compiler;
    Utils::loadConfigs(buildInfo.scriptDir, configs, "config_compiler.props");
    for (auto it = buildInfo.configs.begin(); it != buildInfo.configs.end(); ++it) {
        configs[it->first] = it->second;
    }
    if (configs.size() == 0) {
        Utils::throwError("Load config.props file fail");
    }
    compHome = config(compiler + ".home", "");
    outPodDir = buildInfo.outDir / buildInfo.name;
    objDir = buildInfo.scriptDir / ("../build/obj-" + buildInfo.name + "-" + compiler + "-" + buildInfo.debug);
    fs::create_directories(objDir);
}

void CompileCpp::init() {
    // Create directories
    fs::create_directories(outPodDir);

    fs::path dir = (buildInfo.outType == TargetType::exe) ? "bin/" : "lib/";
    outBinDir = outPodDir / dir;
    fs::create_directories(outBinDir);

    outFile = outBinDir / buildInfo.name;
    fs::path outLibFile = outBinDir / ("lib" + buildInfo.name);

    // Initialize meta data
    meta.clear();
    meta["pod.name"] = buildInfo.name;
    meta["pod.version"] = buildInfo.version;
    
    std::string dependsStr;
    for (size_t i = 0; i < buildInfo.depends.size(); ++i) {
        dependsStr += buildInfo.depends[i].toStr();
        if (i < buildInfo.depends.size() - 1) {
            dependsStr += ";";
        }
    }
    meta["pod.depends"] = dependsStr;
    meta["pod.summary"] = buildInfo.summary;
    
    // Get current time
    std::time_t t = std::time(nullptr);
    meta["pod.buildTime"] = std::to_string(t);
    meta["pod.compiler"] = compiler;

    // Initialize includes
    if (buildInfo.includeDst.empty()) {
        std::vector<std::string> includes;
        for (const auto& includeDir : buildInfo.installHeaders) {
            if (fs::is_directory(includeDir)) {
                fs::path absIncludeDir = fs::absolute(includeDir);
                includes.push_back(absIncludeDir.generic_string());
            }
        }
        if (!includes.empty()) {
            std::string includesStr;
            for (size_t i = 0; i < includes.size(); ++i) {
                includesStr += includes[i];
                if (i < includes.size() - 1) {
                    includesStr += ",";
                }
            }
            meta["pod.includes"] = includesStr;
        }
        meta["pod.includesRewrite"] = (includes.size() == buildInfo.installHeaders.size()) ? "true" : "false";
    }

    //temp fix emcc
    if (strcmp(Utils::osName(), "win32") == 0) {
      fixWin32(configs, "emcc.ar", "emar");
      fixWin32(configs, "emcc.name@{cpp}", "emcc");
      fixWin32(configs, "emcc.name@{c}", "emcc");
      fixWin32(configs, "emcc.link", "emcc");
    }
    
    // Add common configs
    configs["outFile"] = fileToStr(outFile);
    configs["outLibFile"] = fileToStr(outLibFile);
    configs["cflags"] = "";
    configs["cppflags"] = "";
    configs["linkflags"] = "";

    // Add buildInfo.extConfigs
    for (const auto& [k, v] : buildInfo.extConfigs) {
        configs[k] = v;
    }

    // Apply macros for list
    std::map<std::string, std::vector<std::string>> params;
    params["libNames"] = buildInfo.libs;
    params["defines"] = buildInfo.defines;

    std::vector<std::string> incDirsStr;
    for (const auto& adir : buildInfo.incDirs) {
        incDirsStr.push_back(fileToStr(adir));
    }
    params["incDirs"] = incDirsStr;

    std::vector<std::string> libDirsStr;
    for (const auto& adir : buildInfo.libDirs) {
        libDirsStr.push_back(fileToStr(adir));
    }
    params["libDirs"] = libDirsStr;

    std::vector<std::string> objList;
    for (const auto& f : buildInfo.sources) {
        fs::path objFile = getObjFile(f);
        fs::path curDir = fs::current_path();
        fs::path relObjFile = fs::relative(objFile, curDir);
        objList.push_back(fileToStr(relObjFile));
    }
    params["objList"] = objList;

    applayMacrosForList(params);
    selectMacros(buildInfo.debug);
    fileDirtyMap.clear();

    // Delete old lib file
    fs::path oldFile = outBinDir / ("lib" + buildInfo.name + ".a");
    if (fs::exists(oldFile)) {
        fs::remove(oldFile);
    }
}

fs::path CompileCpp::getObjFile(const fs::path& srcFile) const {
    std::string pathStr = srcFile.generic_string();
    std::string scriptDirStr = buildInfo.scriptDir.generic_string();
    std::string objName;

    if (pathStr.find(scriptDirStr) == 0) {
        objName = pathStr.substr(scriptDirStr.size());
        // Replace .. with _
        size_t pos;
        while ((pos = objName.find("..")) != std::string::npos) {
            objName.replace(pos, 2, "_");
        }
    } else {
        auto path = srcFile.relative_path();
        if (path.empty()) {
            objName = pathStr;
        } else if (path.parent_path().empty()) {
            objName = path.generic_string();
        } else {
            objName = path.parent_path().generic_string() + "/" + path.filename().generic_string();
        }
    }

    fs::path objNamePath = (objName + ".o");
    fs::path objFile = objDir / objNamePath.relative_path();
    return objFile;
}

void CompileCpp::run() {
    std::cout << "Compile module: " << buildInfo.name << " compiler: " << compiler << std::endl;

    try {
        init();
    } catch (const std::exception& e) {
        std::cerr << "CompileCpp init failed: " << e.what() << std::endl;
        return;
    }

    try {
        for (const auto& srcFile : buildInfo.sources) {
            // Set srcFile in configs
            configs["srcFile"] = fileToStr(srcFile);

            fs::path objFile = getObjFile(srcFile);
            if (fs::exists(objFile) && fs::is_regular_file(objFile)) {
                auto objTime = fs::last_write_time(objFile);
                // Subtract 1 second
                auto srcTime = fs::last_write_time(srcFile);
                if (!isDirty(srcFile, objTime)) {
                    continue;
                }
            }

            // Create directory if not exists
            fs::create_directories(objFile.parent_path());

            // Set objFile in configs
            configs["objFile"] = fileToStr(objFile);

            // Select macros based on file type
            if (srcFile.extension() == ".c") {
                selectMacros("c");
            } else {
                selectMacros("cpp");
            }

            exeCmd("comp");
        }

        // Link
        if (buildInfo.outType == TargetType::lib) {
            exeCmd("lib");
        } else {
            exeCmd(buildInfo.outType == TargetType::dll ? "dll" : "exe");
        }

        // Install
        install();

        std::cout << "BUILD SUCCESS" << std::endl;

        // Execute if needed
        if (buildInfo.execute && buildInfo.outType == TargetType::exe) {
            exeBin();
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        std::cout << "BUILD FAIL" << std::endl;
    }
}

std::string CompileCpp::fileToStr(const fs::path& f) {
    std::string path = f.generic_string();
    // Replace spaces with ::
    size_t pos;
    while ((pos = path.find(' ')) != std::string::npos) {
        path.replace(pos, 1, "::");
    }
    return path;
}

std::string CompileCpp::config(const std::string& name, const std::string& def) const {
    // Check environment variable
    std::string envName = "FAN_BUILD_";
    for (char c : name) {
        envName += (char)std::toupper(c);
    }
    const char* envValue = std::getenv(envName.c_str());
    if (envValue) {
        return envValue;
    }

    // Check configs
    auto it = configs.find(name);
    if (it != configs.end()) {
        return it->second;
    }

    return def;
}

void CompileCpp::clean() {
    if (buildInfo.outType != TargetType::exe) {
        if (fs::exists(outPodDir)) {
            fs::remove_all(outPodDir);
        }
    }
    if (fs::exists(objDir)) {
        fs::remove_all(objDir);
    }
}

void CompileCpp::fixWin32(std::map<std::string, std::string>& configs_, const std::string& key, const std::string& value) {
    auto it = configs_.find(key);
    if (it != configs_.end()) {
        if (it->second.find(".bat") == std::string::npos) {
            size_t pos = it->second.find(value);
            if (pos != std::string::npos) {
                it->second.replace(pos, value.size(), value + ".bat");
            }
        }
    }
}

void CompileCpp::selectMacros(const std::string& mode) {
    // Create a copy of configs to iterate over
    auto configsCopy = configs;
    
    for (const auto& [k, v] : configsCopy) {
        size_t pos = k.find("@{");
        if (pos != std::string::npos) {
            size_t endPos = k.find("}", pos + 2);
            if (endPos != std::string::npos) {
                std::string macroKey = k.substr(pos + 2, endPos - (pos + 2));
                if (macroKey == mode) {
                    std::string newKey = k.substr(0, pos) + k.substr(endPos + 1);
                    configs[newKey] = v;
                }
            }
        }
    }
    
    configs["mode"] = mode;
}

void CompileCpp::applayMacrosForList(const std::map<std::string, std::vector<std::string>>& params) {
    // Create a copy of configs to iterate over
    auto configsCopy = configs;
    
    for (const auto& [k, v] : configsCopy) {
        if (v.size() > 2 && v[0] == '[' && v[v.size() - 1] == ']') {
            std::string pattern = v.substr(1, v.size() - 2);
            
            // Find the macro key in the pattern
            size_t pos = pattern.find("@{");
            if (pos != std::string::npos) {
                size_t endPos = pattern.find("}", pos + 2);
                if (endPos != std::string::npos) {
                    std::string key = pattern.substr(pos + 2, endPos - (pos + 2));
                    
                    // Check if this key exists in params
                    auto it = params.find(key);
                    if (it != params.end()) {
                        const std::vector<std::string>& list = it->second;
                        std::string flattened;
                        
                        for (size_t i = 0; i < list.size(); ++i) {
                            std::string item = pattern;
                            size_t itemPos = item.find("@{");
                            if (itemPos != std::string::npos) {
                                size_t itemEndPos = item.find("}", itemPos + 2);
                                if (itemEndPos != std::string::npos) {
                                    item.replace(itemPos, itemEndPos - itemPos + 1, list[i]);
                                }
                            }
                            flattened += item;
                            if (i < list.size() - 1) {
                                flattened += " ";
                            }
                        }
                        
                        configs[k] = flattened;
                    }
                }
            }
        }
    }
    
    // Add params to configs for direct use
    for (const auto& [k, v] : params) {
        std::string value;
        for (size_t i = 0; i < v.size(); ++i) {
            value += v[i];
            if (i < v.size() - 1) {
                value += " ";
            }
        }
        configs[k] = value;
    }
}

std::string CompileCpp::applyMacros(const std::string& pattern, const std::map<std::string, std::string>& macros) {
    std::string result = pattern;
    
    // Replace macros
    size_t pos = 0;
    while ((pos = result.find("@{", pos)) != std::string::npos) {
        size_t endPos = result.find("}", pos + 2);
        if (endPos != std::string::npos) {
            std::string key = result.substr(pos + 2, endPos - (pos + 2));
            auto it = macros.find(key);
            if (it != macros.end()) {
                result.replace(pos, endPos - pos + 1, it->second);
                pos = 0; // Reset position to handle nested macros
            } else {
                pos = endPos + 1;
            }
        } else {
            break;
        }
    }
    
    return result;
}

void CompileCpp::exeCmd(const std::string& name) {
    std::string cmd;
    std::string key = compiler + "." + name;
    auto it = configs.find(key);
    if (it != configs.end()) {
        cmd = it->second;
    }

    if (cmd.empty()) {
        Utils::throwError("Command not found in config file: " + key);
    }

    cmd = applyMacros(cmd, configs);
    
    // Replace spaces in compHome with ::
    std::string compHomeWithEscapedSpaces = Utils::replaceAll(compHome.generic_string(), " ", "::");
    cmd = compHomeWithEscapedSpaces + cmd;

    // Split command and replace :: with spaces
    std::vector<std::string> cmds;
    std::vector<std::string> tcmds = Utils::split(cmd, ' ');
    for (auto& token : tcmds) {
        std::string processedToken = Utils::replaceAll(token, "::", " ");
        // Add quotes around the command if it contains spaces
        if (processedToken.find(' ') != std::string::npos) {
            processedToken = "\"" + processedToken + "\"";
        }
        cmds.push_back(processedToken);
    }

    // Build command string
    std::string cmdStr;
    for (size_t i = 0; i < cmds.size(); ++i) {
        cmdStr += cmds[i];
        if (i < cmds.size() - 1) {
            cmdStr += " ";
        }
    }

    // Set environment variables
    std::string inc = config(compiler + ".include_dir", "");
    std::string lib = config(compiler + ".lib_dir", "");
    
    if (!inc.empty()) {
        // Set INCLUDE environment variable
        std::string includeEnv = inc;
        Utils::setenv("INCLUDE", includeEnv.c_str());
    }
    
    if (!lib.empty()) {
        // Set LIB environment variable
        std::string libEnv = lib;
        Utils::setenv("LIB", libEnv.c_str());
    }

    std::cout << "Exec " << cmdStr << std::endl;

    // Execute command
    int result = std::system(cmdStr.c_str());
    if (result != 0) {
        Utils::throwError("Exec failed [" + cmd + "]");
    }

}

void CompileCpp::exeBin() {
    std::string cmd = outFile.generic_string();
    std::cout << "Exec " << cmd << std::endl;
    std::system(cmd.c_str());
}

fs::path CompileCpp::searchHeaderFile(const fs::path& self, const std::string& name) const {
    fs::path f = self.parent_path() / name;
    if (fs::exists(f) && fs::is_regular_file(f)) {
        return f;
    }

    for (const auto& p : buildInfo.incDirs) {
        f = p / name;
        if (fs::exists(f) && fs::is_regular_file(f)) {
            return f;
        }
    }

    return fs::path();
}

bool CompileCpp::isDirty(const fs::path& srcFile_, const std::filesystem::file_time_type& time) {
    auto srcFile = fs::canonical(srcFile_);
    auto it = fileDirtyMap.find(srcFile);
    if (it != fileDirtyMap.end()) {
        return it->second;
    }

    auto srcTime = fs::last_write_time(srcFile);
    if (srcTime >= time) {
        fileDirtyMap[srcFile] = true;
        return true;
    }

    fileDirtyMap[srcFile] = false;

    // Check includes
    std::ifstream ifs(srcFile);
    if (!ifs.is_open()) {
        return true;
    }

    std::string line;
    while (std::getline(ifs, line)) {
        std::string trimmed = line;
        trimmed.erase(0, trimmed.find_first_not_of(" \t"));
        if (trimmed.substr(0, 8) == "#include") {
            trimmed = trimmed.substr(8);
            trimmed.erase(0, trimmed.find_first_not_of(" \t"));
            if (trimmed.size() > 2 && trimmed[0] == '"' && trimmed.back() == '"') {
                std::string includeName = trimmed.substr(1, trimmed.size() - 2);
                fs::path depend = searchHeaderFile(srcFile, includeName);
                if (depend.empty()) {
                    std::cerr << "Not found include file: " << includeName << " in: " << srcFile.generic_string() << std::endl;
                    continue;
                }
                depend = fs::canonical(depend);
                if (isDirty(depend, time)) {
                    fileDirtyMap[srcFile] = true;
                    return true;
                }
            }
        }
    }

    return false;
}

void CompileCpp::install() {
    // Copy resources
    if (!buildInfo.resDirs.empty()) {
        copyInto(buildInfo.resDirs, outPodDir, false, true);
    }

    // Copy headers
    if (buildInfo.outType != TargetType::exe) {
        copyHeaderFile(outPodDir);

        if (buildInfo.installGlobal) {
            copyHeaderFile(buildInfo.outDir);

            fs::path libDirs = buildInfo.outDir / "lib/";
            fs::create_directories(libDirs);

            fs::path srcLibDir = outPodDir / "lib/";
            if (fs::exists(srcLibDir)) {
                for (const auto& entry : fs::directory_iterator(srcLibDir)) {
                    fs::copy(entry.path(), libDirs / entry.path().filename(), fs::copy_options::overwrite_existing);
                }
            }
        }
    }

    // Write meta.props
    fs::path metaPath = outPodDir / "meta.props";
    std::ofstream ofs(metaPath);
    if (ofs.is_open()) {
        for (const auto& [k, v] : meta) {
            ofs << k << "=" << v << std::endl;
        }
        ofs.close();
    }

    std::cout << "outFile: " << outFile.generic_string() << std::endl;
}

void CompileCpp::copyHeaderFile(const fs::path& outDir) {
    fs::path dstIncludeDir;
    if (!buildInfo.includeDst.empty()) {
        dstIncludeDir = outDir / "include/" / buildInfo.includeDst;
    } else {
        dstIncludeDir = outDir / "include/";
    }
    fs::create_directories(dstIncludeDir);

    copyInto(buildInfo.installHeaders, dstIncludeDir, true, true);
}

void CompileCpp::copyInto(const std::vector<fs::path>& src, const fs::path& dir, bool filter, bool overwrite) {

    for (const auto& uri : src) {
        fs::path f = uri;
        fs::path dst = dir;
        if (!filter) {
            auto filename = f.filename();
            if (filename.empty()) {
                filename = f.parent_path().filename();
            }
            dst = dir / filename;
        }

        if (fs::is_directory(f)) {
            for (const auto& entry : fs::recursive_directory_iterator(f)) {
                fs::path relPath = fs::relative(entry.path(), f);
                fs::path dstPath = dst / relPath;
                if (!fs::is_directory(entry)) {
                    std::string ext = entry.path().extension().generic_string();
                    if (!filter || ext == ".h" || ext == ".hpp" || ext == ".inl") {
                        fs::create_directories(dstPath.parent_path());
                        if (overwrite || !fs::exists(dstPath)) {
                            fs::copy(entry.path(), dstPath, fs::copy_options::overwrite_existing);
                        }
                    }
                }
            }
        } else {
            if (overwrite || !fs::exists(dst)) {
                fs::create_directories(dst);
                fs::path dstPath = dst / f.filename();
                std::string ext = f.extension().generic_string();
                if (!filter || ext == ".h" || ext == ".hpp" || ext == ".inl") {
                    fs::copy(f, dstPath, fs::copy_options::overwrite_existing);
                }
            }
        }
    }
}


