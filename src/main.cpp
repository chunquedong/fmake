#include <iostream>
#include <string>
#include <vector>
#include <filesystem>

#include "BuildCpp.h"
#include "CompileCpp.h"
#include "Generator.h"

namespace fs = std::filesystem;

void printHelp() {
    std::cout << "Usage: fmake [options] [script_file]" << std::endl;
    std::cout << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -?, -help      Show this help message" << std::endl;
    std::cout << "  -f, -force     Force clean build" << std::endl;
    std::cout << "  -G, -generate  Generate make files" << std::endl;
    std::cout << "  -dump          Dump build information" << std::endl;
    std::cout << "  -d, -debug     Enable debug mode" << std::endl;
    std::cout << "  -c, -compiler  Specify compiler" << std::endl;
    std::cout << "  -t, -target    Specify target name" << std::endl;
    std::cout << "  -execute       Execute the built binary" << std::endl;
    std::cout << "  -version       Version information" << std::endl;
    std::cout << std::endl;
}

int main(int argc, char* argv[]) {
    bool force = false;
    bool generate = false;
    bool dump = false;
    bool debug = false;
    bool execute = false;
    std::string compiler;
    std::string scriptPath;
    std::string targetName;

    // Parse command line arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-?" || arg == "-help") {
            printHelp();
            return 0;
        } else if (arg == "-f" || arg == "-force") {
            force = true;
        } else if (arg == "-G" || arg == "-generate") {
            generate = true;
        } else if (arg == "-dump") {
            dump = true;
        } else if (arg == "-d" || arg == "-debug") {
            debug = true;
        } else if (arg == "-c" || arg == "-compiler") {
            if (i + 1 < argc) {
                compiler = argv[++i];
            }
        } else if (arg == "-t" || arg == "-target") {
            if (i + 1 < argc) {
                targetName = argv[++i];
            }
        }
        else if (arg == "-execute") {
            execute = true;
        }
        else if (arg == "-version") {
            printf("fmake 4.0\n");
            return 0;
        }
        else {
            scriptPath = arg;
        }
    }

    if (scriptPath.size() == 0) {
        printHelp();
        return 1;
    }

    fs::path scriptFile = scriptPath;
    if (!fs::exists(scriptFile)) {
        std::cerr << "Error: Script file not found: " << scriptPath << std::endl;
        return 1;
    }
    scriptFile = fs::absolute(scriptFile);

    std::cout << "Input " << scriptFile.generic_string() << std::endl;
    std::vector<IniSection> sections = Utils::readIni(scriptFile);

    int count = 0;
    for (IniSection& section : sections) {
        if (!targetName.empty() && section.name != targetName) {
            continue;
        }
        if (section.name.size() > 0) {
            std::cout << "Target " << section.name << std::endl;
        }
        count++;
        
        BuildCpp build;
        if (debug) {
            build.debug = "debug";
        }
        if (execute) {
            build.execute = execute;
        }
        if (!compiler.empty()) {
            build.compiler = compiler;
        }

        try {
            build.parse(scriptFile, !generate && !dump, section);

            if (generate) {
                Generator generator(build);
                generator.run(force);
            } else if (dump) {
                build.dump();
            } else {
                CompileCpp cc(build);
                if (force) {
                    cc.clean();
                }
                cc.run();
            }
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << std::endl;
            std::cout << "BUILD FAIL" << std::endl;
            return 1;
        }
    }

    if (count == 0 && !targetName.empty()) {
        std::cerr << "Error: Target not found: " << targetName << std::endl;
        return 1;
    }
    return 0;
}
