# Makefile for fmake

# Compiler settings
CXX = D:/Qt/Tools/mingw1310_64/bin/g++.exe
CXXFLAGS = -std=c++17 -Wall -Wextra -Wpedantic
INCLUDES = -I.

# Source files
SRCS = main.cpp BuildCpp.cpp CompileCpp.cpp Generator.cpp Utils.cpp

# Header files
HDRS = src/BuildCpp.h src/CompileCpp.h src/Generator.h src/Utils.h

# Output directory
OUTPUT_DIR = bin

# Output
TARGET = $(OUTPUT_DIR)/fmake.exe

# Object files
OBJS = $(SRCS:.cpp=.o)

# Default target
all: $(OUTPUT_DIR) $(TARGET)

# Create output directory
$(OUTPUT_DIR):
	@if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"

# Link target
$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $(TARGET) $(OBJS)

# Compile source files
%.o: %.cpp $(HDRS)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Clean target
clean:
	@echo Cleaning...
	@del /f /q $(OBJS) $(TARGET) 2>NUL
	@echo Done.

# Phony targets
.PHONY: all clean