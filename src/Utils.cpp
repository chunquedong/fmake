#include "Utils.h"
#include <fstream>
#include <sstream>

#ifdef _WIN32
#include <windows.h>
#elif defined(__linux__)
#include <unistd.h>
#elif defined(__APPLE__)
#include <mach-o/dyld.h>
#endif


std::map<std::string, std::string> Utils::readProps(const fs::path& file) {
    std::map<std::string, std::string> props;
    std::ifstream ifs(file);

    if (!ifs.is_open()) {
        return props;
    }

    std::string line;
    std::string currentLine;

    while (std::getline(ifs, line)) {
        // Trim whitespace from the end
        size_t end = line.find_last_not_of(" \t");
        if (end != std::string::npos) {
            line = line.substr(0, end + 1);
        }

        // Trim whitespace from the beginning
        std::string trimmedLine = Utils::trim(line);
        
        // Skip empty lines and comment lines (starting with // or #)
        if (trimmedLine.empty() || trimmedLine.substr(0, 2) == "//" || trimmedLine.substr(0, 1) == "#") {
            continue;
        }

        // Check if line ends with backslash
        if (!line.empty() && line.back() == '\\') {
            // Remove the backslash and continue reading
            currentLine += line.substr(0, line.size() - 1);
            continue;
        } else {
            // Add the current line to the accumulated line
            currentLine += line;
            
            // Process the complete line
            size_t pos = currentLine.find('=');
            if (pos != std::string::npos) {
                std::string key = currentLine.substr(0, pos);
                std::string value = currentLine.substr(pos + 1);
                
                // Trim whitespace
                key = Utils::trim(key);
                value = Utils::trim(value);
                
                if (!key.empty()) {
                    // Check for duplicate keys
                    if (props.find(key) != props.end()) {
                        Utils::throwError("Duplicate key found in properties file: " + key);
                    }
                    props[key] = value;
                }
            }
            
            // Reset current line
            currentLine.clear();
        }
    }

    ifs.close();
    return props;
}

std::string Utils::trim(const std::string& str) {
    size_t start = str.find_first_not_of(" \t");
    if (start == std::string::npos) {
        return "";
    }
    
    size_t end = str.find_last_not_of(" \t");
    return str.substr(start, end - start + 1);
}

std::string Utils::replaceAll(const std::string& str, const std::string& from, const std::string& to) {
    std::string result = str;
    size_t pos = 0;
    while ((pos = result.find(from, pos)) != std::string::npos) {
        result.replace(pos, from.length(), to);
        pos += to.length();
    }
    return result;
}

std::vector<std::string> Utils::split(const std::string& str, char delimiter) {
    std::vector<std::string> result;
    std::stringstream ss(str);
    std::string item;
    while (std::getline(ss, item, delimiter)) {
        std::string trimmedItem = trim(item);
        result.push_back(trimmedItem);
    }
    return result;
}

std::map<std::string, std::string> Utils::loadConfigs(const fs::path& scriptDir) {
    std::map<std::string, std::string> configs;
    
    // Load config files in order of increasing priority
    // 1. Executable directory (lowest priority)
    fs::path exePath = Utils::exePath();
    if (!exePath.empty()) {
        fs::path configFile = exePath.parent_path() / "config_compiler.props";
        if (fs::exists(configFile)) {
            auto configPropsMap = Utils::readProps(configFile);
            for (const auto& [k, v] : configPropsMap) {
                configs[k] = v;
            }
        }

        configFile = exePath.parent_path() / "config.props";
        if (fs::exists(configFile)) {
            auto configPropsMap = Utils::readProps(configFile);
            for (const auto& [k, v] : configPropsMap) {
                configs[k] = v;
            }
        }
    }

    // 2. Current directory
    fs::path configFile = fs::current_path() / "config.props";
    if (fs::exists(configFile)) {
        auto configPropsMap = Utils::readProps(configFile);
        for (const auto& [k, v] : configPropsMap) {
            configs[k] = v;
        }
    }
    
    // 3. Script directory (highest priority)
    configFile = scriptDir / "config.props";
    if (fs::exists(configFile)) {
        auto configPropsMap = Utils::readProps(configFile);
        for (const auto& [k, v] : configPropsMap) {
            configs[k] = v;
        }
    }
    
    return configs;
}

std::string Utils::exePath() {
    fs::path exePath;
#ifdef _WIN32
    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    exePath = buffer;
#elif defined(__linux__)
    char buffer[PATH_MAX];
    ssize_t count = readlink("/proc/self/exe", buffer, PATH_MAX);
    if (count != -1) {
        buffer[count] = '\0';
        exePath = buffer;
    }
#elif defined(__APPLE__)
    char buffer[PATH_MAX];
    uint32_t size = PATH_MAX;
    if (_NSGetExecutablePath(buffer, &size) == 0) {
        exePath = buffer;
    }
#endif
    return exePath.generic_string();
}


void Utils::setenv(const char* key, const char* value) {
#ifdef _WIN32
    SetEnvironmentVariableA(key, value);
#else
    setenv(key, value, 1);
#endif
}

const char* Utils::osName() {
#ifdef _WIN32
    return "win32";
#endif

#ifdef __linux__
    return "linux";
#endif

#ifdef __APPLE__
    return "macosx";
#endif

#ifdef __unix__
    return "unix";
#endif
    return "";
}

void Utils::throwError(const std::string& message) {
    throw std::runtime_error(message);
}