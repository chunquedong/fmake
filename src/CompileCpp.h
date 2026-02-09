#pragma once

#include <string>
#include <vector>
#include <filesystem>
#include <map>

#include "BuildCpp.h"

namespace fs = std::filesystem;

class CompileCpp {
private:
    // Output file name
    fs::path outFile;

    // Output file pod dir
    fs::path outPodDir;

    // Output file dir
    fs::path outBinDir;

    // Object file directory
    fs::path objDir;

    // Build information
    const BuildCpp& buildInfo;

    // Version
    std::string version;

    // Meta data
    std::map<std::string, std::string> meta;

    // Compiler name
    std::string compiler;

    // Compiler home
    fs::path compHome;

    // Configs.props
    std::map<std::string, std::string> configs;

    // File dirty map
    std::map<fs::path, bool> fileDirtyMap;

public:
    // Constructor
    CompileCpp(const BuildCpp& buildInfo);

    // Run the compiler
    void run();

    // Clean build files
    void clean();

private:
    // Initialize
    void init();

    // Get object file path
    fs::path getObjFile(const fs::path& srcFile) const;

    // Execute command
    void exeCmd(const std::string& name);

    // Execute binary
    void exeBin();

    // Check if file is dirty
    bool isDirty(const fs::path& srcFile, const std::filesystem::file_time_type& time);

    // Search header file
    fs::path searchHeaderFile(const fs::path& self, const std::string& name) const;

    // Install
    void install();

    // Copy header files
    void copyHeaderFile(const fs::path& outDir);

    // Copy into directory
    static void copyInto(const std::vector<fs::path>& src, const fs::path& dir, bool flatten, bool overwrite);

    // Get config value
    std::string config(const std::string& name, const std::string& def) const;

    // Fix win32 paths
    void fixWin32(std::map<std::string, std::string>& configs, const std::string& key, const std::string& value);

    // Select macros
    void selectMacros(const std::string& mode);

    // Apply macros for list
    void applayMacrosForList(const std::map<std::string, std::vector<std::string>>& params);

    // Apply macros
    std::string applyMacros(const std::string& pattern, const std::map<std::string, std::string>& macros);

    // File to string
    static std::string fileToStr(const fs::path& f);
};
