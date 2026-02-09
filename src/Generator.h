#pragma once

#include <string>
#include <vector>
#include <filesystem>
#include <functional>

#include "BuildCpp.h"

namespace fs = std::filesystem;

class Generator {
private:
    const BuildCpp& buildInfo;
    fs::path outDir;
    fs::path fmakeRepoLib;
    bool isQmake;
    fs::path relativePathBase;
public:
    // Constructor
    Generator(const BuildCpp& buildInfo);

    // Run generator
    void run(bool clean);

private:
    // Execute command
    void exe(const fs::path& cmakeDir);

    // Convert path to string
    std::string toPath(const fs::path& uri, bool keepPath = false, const std::string* filter = nullptr) const;

    // Generate QMake file
    void genQmake(std::ofstream& out);

    // Generate CMake file
    void genCmake(std::ofstream& out);

    // Copy header files
    void copyHeaderFile(const std::function<void(const fs::path&, const fs::path&)>& cb);
};
