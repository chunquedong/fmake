#include "BuildCpp.h"
#include "Utils.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <cstdlib>

// Depend class implementation
Depend::Depend(const std::string& depStr) : version(std::string("1.0")) {
    size_t pos = depStr.find(' ');
    if (pos != std::string::npos) {
        name = depStr.substr(0, pos);
        version = depStr.substr(pos + 1);
    } else {
        name = depStr;
    }
}

std::string Depend::toStr() const {
    return name + " " + version;
}

bool Depend::match(const std::string& realVer) const {
    // Simple version matching
    return realVer.find(version) == 0;
}



// BuildCpp class implementation
BuildCpp::BuildCpp() : version(std::string("1.0")), debug("release"), installGlobal(false), execute(false) {
}

void BuildCpp::validate() const {
    if (name.empty()) {
        Utils::throwError("Must set name");
    }
    if (summary.empty()) {
        Utils::throwError("Must set summary");
    }
}

std::vector<fs::path> BuildCpp::srcList(const std::vector<fs::path>& srcDirs_, const std::regex* excludeSrc_) const {
    std::vector<fs::path> srcs;

    for (const auto& path : srcDirs_) {
        if (fs::is_directory(path)) {
            for (const auto& entry : fs::directory_iterator(path)) {
                if (fs::is_regular_file(entry)) {
                    std::string ext = entry.path().extension().generic_string();
                    if (ext == ".cpp" || ext == ".c" || ext == ".cc" || ext == ".cxx" || ext == ".m" || ext == ".C" || ext == ".c++") {
                        if (excludeSrc_) {
                            std::string relPath = fs::relative(entry.path(), scriptDir).generic_string();
                            if (!std::regex_match(relPath, *excludeSrc_)) {
                                srcs.push_back(entry.path());
                            }
                        } else {
                            srcs.push_back(entry.path());
                        }
                    }
                }
            }
        }
        else {
            srcs.push_back(path);
        }
    }

    return srcs;
}

std::vector<fs::path> BuildCpp::allDirs(const fs::path& scriptDir, const fs::path& dir) {
    std::vector<fs::path> subs;
    fs::path base = scriptDir;
    fs::path fullPath = base / dir;

    if (fs::exists(fullPath) && fs::is_directory(fullPath)) {
        for (const auto& entry : fs::recursive_directory_iterator(fullPath)) {
            if (fs::is_directory(entry)) {
                subs.push_back(entry.path());
            }
        }
    }

    return subs;
}

std::vector<fs::path> BuildCpp::parseDirs(const std::string* str, const std::vector<fs::path>& defV) const {
    if (!str) {
        return defV;
    }

    std::vector<fs::path> srcDirs_;
    std::vector<std::string> tokens = Utils::split(*str, ',');

    for (const auto& token : tokens) {
        if (token.empty()) {
            continue;
        }

        if (!token.empty() && token.back() == '*') {
            std::string dirStr = token.substr(0, token.size() - 1);
            fs::path srcUri = scriptDir / dirStr;
            std::vector<fs::path> dirs = allDirs(scriptDir, srcUri);
            srcDirs_.insert(srcDirs_.end(), dirs.begin(), dirs.end());
        } else {
            fs::path uri = scriptDir / token;
            if (token == "./") {
                uri = scriptDir;
            }
            if (!fs::exists(uri)) {
                Utils::throwError("Invalid file: " + uri.generic_string());
            }
            srcDirs_.push_back(uri);
        }
    }

    return srcDirs_;
}

void BuildCpp::getStartsWith(const std::string& prefix, const std::map<std::string, std::string>& props, 
                          std::map<std::string, std::string>& map) const {
    for (const auto& [k, v] : props) {
        if (k.substr(0, prefix.size()) == prefix) {
            std::string key = k.substr(prefix.size());
            map[key] = v;
        }
    }
}

void BuildCpp::osParse(const std::string& os, const std::map<std::string, std::string>& props) {
    // Get name
    auto it = props.find(os + "name");
    if (it != props.end()) {
        name = it->second;
    }

    // Get summary
    it = props.find(os + "summary");
    if (it != props.end()) {
        summary = it->second;
    }

    // Get version
    it = props.find(os + "version");
    if (it != props.end()) {
        version = it->second;
    }

    // Get depends
    it = props.find(os + "depends");
    if (it != props.end()) {
        std::vector<std::string> tokens = Utils::split(it->second, ',');
        for (const auto& token : tokens) {
            if (!token.empty()) {
                depends.emplace_back(token);
            }
        }
    }

    // Get srcDirs
    std::string srcDirsStr;
    it = props.find(os + "srcDirs");
    if (it != props.end()) {
        srcDirsStr = it->second;
    }
    std::vector<fs::path> parsedSrcDirs = parseDirs(&srcDirsStr, {});

    // Get excludeSrc
    it = props.find(os + "excludeSrc");
    if (it != props.end()) {
        excludeSrc = it->second;
    }

    srcDirs.insert(srcDirs.end(), parsedSrcDirs.begin(), parsedSrcDirs.end());

    // Get includeDir
    it = props.find(os + "incDir");
    if (it != props.end()) {
        fs::path incDir = scriptDir / it->second;
        installHeaders.push_back(incDir);
        if (fs::is_directory(incDir)) {
            incDirs.push_back(incDir);
        }
    }

    // Get incDirs
    std::string incDirsStr;
    it = props.find(os + "incDirs");
    if (it != props.end()) {
        incDirsStr = it->second;
    }
    std::vector<fs::path> parsedIncDirs = parseDirs(&incDirsStr, {});
    for (const auto& incdir : parsedIncDirs) {
        installHeaders.push_back(incdir);
        if (fs::is_directory(incdir)) {
            incDirs.push_back(incdir);
        }
    }

    // Get includeDst
    it = props.find(os + "includeDst");
    if (it != props.end()) {
        includeDst = it->second;
    }

    // Get resDirs
    std::string resDirsStr;
    it = props.find(os + "resDirs");
    if (it != props.end()) {
        resDirsStr = it->second;
    }
    std::vector<fs::path> parsedResDirs = parseDirs(&resDirsStr, {});
    resDirs.insert(resDirs.end(), parsedResDirs.begin(), parsedResDirs.end());

    // Get outType
    it = props.find(os + "outType");
    if (it != props.end()) {
        const std::string& v = it->second;
        if (v == "exe") {
            outType = TargetType::exe;
        } else if (v == "dll") {
            outType = TargetType::dll;
        } else if (v == "lib") {
            outType = TargetType::lib;
        }
    }

    // Get extLibs
    it = props.find(os + "extLibs");
    if (it != props.end()) {
        std::vector<std::string> tokens = Utils::split(it->second, ',');
        for (const auto& token : tokens) {
            if (!token.empty()) {
                libs.push_back(token);
            }
        }
    }

    // Get debugExtLibs
    std::string debugExtLibsStr;
    it = props.find(os + debug + ".extLibs");
    if (it != props.end()) {
        debugExtLibsStr = it->second;
    }
    if (!debugExtLibsStr.empty()) {
        std::vector<std::string> tokens = Utils::split(debugExtLibsStr, ',');
        for (const auto& token : tokens) {
            if (!token.empty()) {
                libs.push_back(token);
            }
        }
    }

    // Get defines
    it = props.find(os + "defines");
    if (it != props.end()) {
        std::vector<std::string> tokens = Utils::split(it->second, ',');
        for (const auto& token : tokens) {
            if (!token.empty()) {
                defines.push_back(token);
            }
        }
    }

    // Get debugDefines
    std::string debugDefinesStr;
    it = props.find(os + debug + ".defines");
    if (it != props.end()) {
        debugDefinesStr = it->second;
    }
    if (!debugDefinesStr.empty()) {
        std::vector<std::string> tokens = Utils::split(debugDefinesStr, ',');
        for (const auto& token : tokens) {
            if (!token.empty()) {
                defines.push_back(token);
            }
        }
    }

    // Get extIncDirs
    std::string extIncDirsStr;
    it = props.find(os + "extIncDirs");
    if (it != props.end()) {
        extIncDirsStr = it->second;
    }
    std::vector<fs::path> parsedExtIncDirs = parseDirs(&extIncDirsStr, {});
    incDirs.insert(incDirs.end(), parsedExtIncDirs.begin(), parsedExtIncDirs.end());

    // Get extLibDirs
    std::string extLibDirsStr;
    it = props.find(os + "extLibDirs");
    if (it != props.end()) {
        extLibDirsStr = it->second;
    }
    std::vector<fs::path> parsedExtLibDirs = parseDirs(&extLibDirsStr, {});
    libDirs.insert(libDirs.end(), parsedExtLibDirs.begin(), parsedExtLibDirs.end());

    // Get outDir
    it = props.find(os + "outDir");
    if (it != props.end()) {
        outDir = fs::canonical(it->second);
    }

    // Get extConfigs
    getStartsWith(os + "extConfigs.", props, extConfigs);
}

fs::path BuildCpp::getFmakeRepoDir() {
    const char* devHome = std::getenv("FMAKE_REPO");
    std::string devHomeStr;

    if (devHome) {
        devHomeStr = devHome;
        // Windows driver name
        if (devHomeStr.size() > 1 && std::isalpha(devHomeStr[0]) && devHomeStr[1] == ':') {
            devHomeStr = fs::canonical(devHomeStr).generic_string();
        }
    }

    if (devHomeStr.empty()) {
        // Try to get from config
        // Use user's home directory
        const char* homeEnv = nullptr;
        #ifdef _WIN32
        homeEnv = std::getenv("USERPROFILE");
        #else
        homeEnv = std::getenv("HOME");
        #endif
        
        if (homeEnv) {
            devHomeStr = std::string(homeEnv) + "/fmakeRepo/";
        } else {
            // Fallback to current directory if home directory not found
            devHomeStr = fs::current_path().generic_string() + "/fmakeRepo/";
        }
    }

    fs::path path = devHomeStr;
    if (!fs::exists(path)) {
        fs::create_directories(path);
    } else if (!fs::is_directory(path)) {
        Utils::throwError("Invalid dir URI for '" + devHomeStr + "'");
    }

    return path;
}

void BuildCpp::applayDepends(bool checkError) {
    fs::path outHome = outDir;

    for (const auto& dep : depends) {
        bool includesRewrite = false;
        fs::path metaPath = outHome / dep.name / "meta.props";

        if (fs::exists(metaPath)) {
            auto meta = Utils::readProps(metaPath);
            std::string rversion;
            for (const auto& [k, v] : meta) {
                if (k == "pod.version") {
                    rversion = v;
                    break;
                }
            }

            if (!dep.match(rversion)) {
                Utils::throwError("Cannot resolve depend: '" + dep.name + " " + rversion + "' != '" + dep.toStr() + "'");
            }

            for (const auto& [k, v] : meta) {
                if (k == "pod.includesRewrite") {
                    includesRewrite = (v == "true");
                } else if (k == "pod.includes") {
                    std::vector<std::string> tokens = Utils::split(v, ',');
                    for (const auto& token : tokens) {
                        if (!token.empty()) {
                            fs::path includePath;
                            if (token[0] == '/') {
                                includePath = token.substr(1, token.size() - 1);
                            }
                            else {
                                includePath = token;
                            }
                            if (fs::exists(includePath)) {
                                incDirs.push_back(includePath);
                            } else {
                                includesRewrite = false;
                            }
                        }
                    }
                }
            }
        }

        if (!includesRewrite) {
            fs::path depIncPath = outHome / dep.name / "include/";
            if (!fs::exists(depIncPath)) {
                if (checkError) {
                    Utils::throwError("Don't find the depend " + dep.toStr());
                } else {
                    std::cerr << "Don't find the depend " + dep.toStr() << std::endl;
                }
            }
            incDirs.push_back(depIncPath);
        }

        fs::path depLibPath = outHome / dep.name / "lib/";
        if (!fs::exists(depLibPath)) {
            if (checkError) {
                Utils::throwError("Don't find the depend " + dep.toStr());
            } else {
                std::cerr << "Don't find the depend " + dep.toStr() << std::endl;
            }
        }
        libDirs.push_back(depLibPath);
    }

    for (const auto& dep : depends) {
        fs::path depLibPath = outHome / dep.name / "lib/";
        int count = 0;

        if (fs::exists(depLibPath)) {
            for (const auto& entry : fs::directory_iterator(depLibPath)) {
                if (fs::is_regular_file(entry)) {
                    std::string ext = entry.path().extension().generic_string();
                    if (ext == ".a" || ext == ".so") {
                        std::string libName = entry.path().filename().generic_string();
                        if (libName.substr(0, 3) == "lib" && libName.substr(libName.size() - 2) == ".a") {
                            libs.push_back(libName.substr(3, libName.size() - 5));
                        } else if (libName.substr(0, 3) == "lib" && libName.substr(libName.size() - 3) == ".so") {
                            libs.push_back(libName.substr(3, libName.size() - 6));
                        } else {
                            libs.push_back(libName);
                        }
                        count++;
                    }
                }
            }
        }

        if (count == 0) {
            if (fs::exists(depLibPath)) {
                for (const auto& entry : fs::directory_iterator(depLibPath)) {
                    if (fs::is_regular_file(entry)) {
                        std::string ext = entry.path().extension().generic_string();
                        if (ext == ".lib") {
                            libs.push_back(entry.path().filename().generic_string());
                            count++;
                        }
                    }
                }
            }
        }

        if (count == 0) {
            if (checkError) {
                Utils::throwError("Don't find any lib in " + depLibPath.generic_string());
            } else {
                std::cerr << "Don't find any lib in " + depLibPath.generic_string() << std::endl;
            }
        }
    }
}



void BuildCpp::parse(const fs::path& scriptFile, bool checkError) {
    std::cout << "Input " << scriptFile.generic_string() << std::endl;
    scriptDir = scriptFile.parent_path();
    auto propsMap = Utils::readProps(scriptFile);

    // Parse general config
    osParse("", propsMap);

    // Parse OS specific config
    std::string os = Utils::osName();
    if (os != "win32") {
      osParse("non-win.", propsMap);
    }
    osParse(os + ".", propsMap);

    // Parse compiler
    if (compiler.empty()) {
        auto it = propsMap.find("compiler");
        if (it != propsMap.end()) {
            compiler = it->second;
        }

        if (compiler.empty()) {
            #ifdef _WIN32
            compiler = "msvc";
            #else
            compiler = "gcc";
            #endif
        }
    }

    osParse(compiler + ".", propsMap);
    osParse(os + "-" + compiler + ".", propsMap);

    // Parse installGlobal
    installGlobal = false;
    auto it = propsMap.find("installGlobal");
    if (it != propsMap.end() && it->second == "true") {
        installGlobal = true;
    }

    // Parse sources
    std::regex* excludeRegex = nullptr;
    std::regex excludeRegexObj;
    if (!excludeSrc.empty()) {
        try {
            excludeRegexObj = std::regex(excludeSrc);
            excludeRegex = &excludeRegexObj;
        } catch (...) {
            // Invalid regex, ignore
        }
    }

    auto parsedSources = srcList(srcDirs, excludeRegex);
    sources.insert(sources.end(), parsedSources.begin(), parsedSources.end());

    // Set default outDir
    if (outDir.empty()) {
        fs::path outDirFile = getFmakeRepoDir() / compiler / debug;
        fs::create_directories(outDirFile);
        outDir = outDirFile;
    }

    // Apply dependencies
    applayDepends(checkError);

    // Reverse libs
    std::reverse(libs.begin(), libs.end());

    // Validate
    validate();
}

void BuildCpp::dump() const {
    std::cout << "name: " << name << std::endl;
    std::cout << "summary: " << summary << std::endl;
    std::cout << "outDir: " << outDir.generic_string() << std::endl;
    std::cout << "outType: " << static_cast<int>(outType) << std::endl;
    std::cout << "debug: " << debug << std::endl;
    std::cout << "version: " << version << std::endl;
    std::cout << "compiler: " << compiler << std::endl;
    std::cout << "installGlobal: " << (installGlobal ? "true" : "false") << std::endl;
    std::cout << "execute: " << (execute ? "true" : "false") << std::endl;

    std::cout << "depends: " << std::endl;
    for (const auto& dep : depends) {
        std::cout << "  " << dep.toStr() << std::endl;
    }

    std::cout << "libs: " << std::endl;
    for (const auto& lib : libs) {
        std::cout << "  " << lib << std::endl;
    }

    std::cout << "defines: " << std::endl;
    for (const auto& define : defines) {
        std::cout << "  " << define << std::endl;
    }

    std::cout << "incDirs: " << std::endl;
    for (const auto& dir : incDirs) {
        std::cout << "  " << dir.generic_string() << std::endl;
    }

    std::cout << "libDirs: " << std::endl;
    for (const auto& dir : libDirs) {
        std::cout << "  " << dir.generic_string() << std::endl;
    }

    std::cout << "sources: " << std::endl;
    for (const auto& src : sources) {
        std::cout << "  " << src.generic_string() << std::endl;
    }

    std::cout << "installHeaders: " << std::endl;
    for (const auto& header : installHeaders) {
        std::cout << "  " << header.generic_string() << std::endl;
    }

    std::cout << "resDirs: " << std::endl;
    for (const auto& dir : resDirs) {
        std::cout << "  " << dir.generic_string() << std::endl;
    }

    std::cout << "extConfigs: " << std::endl;
    for (const auto& [k, v] : extConfigs) {
        std::cout << "  " << k << " = " << v << std::endl;
    }
}
