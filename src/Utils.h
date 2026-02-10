#pragma once

#include <string>
#include <vector>
#include <map>
#include <filesystem>

namespace fs = std::filesystem;

class Utils {
public:
    /**
     * Read properties from file
     * Handles line continuation with backslash at the end
     * Throws exception if duplicate keys are found
     */
    static std::map<std::string, std::string> readProps(const fs::path& file);

    /**
     * Replace all occurrences of a substring in a string
     */
    static std::string replaceAll(const std::string& str, const std::string& from, const std::string& to);

    /**
     * Split a string into a vector of strings using a delimiter
     */
    static std::vector<std::string> split(const std::string& str, char delimiter);

    static std::string exePath();
    static void setenv(const char* key, const char* value);
    
    /**
     * Load configurations from multiple locations and merge them into a single map
     */
    static void loadConfigs(const fs::path& scriptDir, std::map<std::string, std::string>& configs, const char* file);
    
    /**
     * Throw a runtime error with the given message
     */
    static void throwError(const std::string& message);

    static const char* osName();
private:
    /**
     * Trim whitespace from string
     */
    static std::string trim(const std::string& str);
};
