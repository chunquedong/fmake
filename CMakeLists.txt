cmake_minimum_required(VERSION 3.10)
project(fmake)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# Source files
set(SOURCE_FILES
    src/main.cpp
    src/BuildCpp.cpp
    src/CompileCpp.cpp
    src/Generator.cpp
    src/Utils.cpp
)

# Header files
set(HEADER_FILES
    src/BuildCpp.h
    src/CompileCpp.h
    src/Generator.h
    src/Utils.h
)

# Add executable
add_executable(fmake ${SOURCE_FILES} ${HEADER_FILES})

# Set output directory
set(OUTPUT_DIR ${CMAKE_SOURCE_DIR}/bin)
set_target_properties(fmake PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_DIR}
    RUNTIME_OUTPUT_DIRECTORY_DEBUG ${OUTPUT_DIR}
    RUNTIME_OUTPUT_DIRECTORY_RELEASE ${OUTPUT_DIR}
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO ${OUTPUT_DIR}
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL ${OUTPUT_DIR}
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

# Add compiler options
if(MSVC)
    target_compile_options(fmake PRIVATE /W4 /D_CRT_SECURE_NO_WARNINGS)
else()
    target_compile_options(fmake PRIVATE -Wall -Wextra -Wpedantic)
endif()

# Add include directories
target_include_directories(fmake PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Install
install(TARGETS fmake DESTINATION bin)
