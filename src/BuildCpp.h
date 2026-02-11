#pragma once

#include <string>
#include <vector>
#include <filesystem>
#include <regex>
#include <map>

namespace fs = std::filesystem;

// Output type
enum class TargetType {
    exe,    // executable file
    dll,    // dynamic link library
    lib     // static link library
};

// Dependency class
class Depend {
public:
    std::string name;
    std::string version;

    Depend(const std::string& depStr);
    std::string toStr() const;
    bool match(const std::string& ver) const;
};

// BuildCpp class
class BuildCpp {
public:
    // Lib name
    std::string name;

    // Description of pod
    std::string summary;

    // Output file dir
    fs::path outDir;

    // Lib depends
    std::vector<Depend> depends;

    // Version
    std::string version;

    // Output target type
    TargetType outType;

    // Debug mode
    std::string debug;

    // List of ext librarie to link in
    std::vector<std::string> libs;

    // List of macro define
    std::vector<std::string> defines;

    // List of include directories
    std::vector<fs::path> incDirs;

    // List of lib directories
    std::vector<fs::path> libDirs;

    // List of source files
    std::vector<fs::path> sources;

    // Make file location
    fs::path scriptDir;

    // Self public include to install
    std::vector<fs::path> installHeaders;

    // Header file install destination directories
    std::string includeDst;

    // List of resource directories
    std::vector<fs::path> resDirs;

    // Ext compiler options
    std::map<std::string, std::string> extConfigs;

    // Exclude src file by regex
    std::string excludeSrc;

    // Src directories
    std::vector<fs::path> srcDirs;

    // Install global
    bool installGlobal;

    // Compiler name
    std::string compiler;

    // Execute build result
    bool execute;

    std::map<std::string, std::string> configs;

    // Constructor
    BuildCpp();

    // Parse build script
    void parse(const fs::path& scriptFile, bool checkError);

    // Apply dependencies
    void applayDepends(bool checkError);

    // Dump build info
    void dump() const;

private:
    // Validate build info
    void validate() const;

    // Get source files list
    std::vector<fs::path> srcList(const std::vector<fs::path>& srcDirs, const std::regex* excludeSrc) const;

    // Get all subdirectories
    static std::vector<fs::path> allDirs(const fs::path& scriptDir, const fs::path& dir);

    // Parse directories from string
    std::vector<fs::path> parseDirs(const std::string* str, const std::vector<fs::path>& defV) const;

    // OS specific parse
    void osParse(const std::string& os, const std::map<std::string, std::string>& props);

    // Get fmake repo directory
    fs::path getFmakeRepoDir();

    // Get starts with
    void getStartsWith(const std::string& prefix, const std::map<std::string, std::string>& props, 
                      std::map<std::string, std::string>& map) const;


};
