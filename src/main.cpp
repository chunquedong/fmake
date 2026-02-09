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
    std::cout << "  -execute       Execute the built binary" << std::endl;
    std::cout << "  -version       Version information" << std::endl;
    std::cout << std::endl;
    std::cout << "Default script file: fmake.props" << std::endl;
}

int main(int argc, char* argv[]) {
    bool force = false;
    bool generate = false;
    bool dump = false;
    bool debug = false;
    bool execute = false;
    std::string compiler;
    std::string scriptPath = "fmake.props";

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
        } else if (arg == "-execute") {
            execute = true;
        }
        else if (arg == "-version") {
            printf("fmake 3.0\n");
        }
        else {
            scriptPath = arg;
        }
    }

    fs::path scriptFile = scriptPath;
    if (!fs::exists(scriptFile)) {
        std::cerr << "Error: Script file not found: " << scriptPath << std::endl;
        return 1;
    }

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
        build.parse(scriptFile, !generate && !dump);

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
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
}
