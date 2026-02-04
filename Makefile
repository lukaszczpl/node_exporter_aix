# ============================================================================
# node_exporter_aix Build Configuration
# ============================================================================

# Compiler Configuration
# Recommended: g++ 9.x or newer for full C++17 support
# Force gcc/g++ usage (override Make's default cc)
# To use different compiler: make CXX=/path/to/compiler CC=/path/to/gcc
CXX = g++
CC = gcc
# C compilation flags for civetweb (AIX compatibility)
CFLAGS = -D_LINUX_SOURCE_COMPAT -DNEED_TIMEGM

# Debug Configuration
# Set DEBUG=1 for debug build: make DEBUG=1
# Debug build includes symbols (-g) and disables optimization (-O0)
DEBUG ?= 0
ifeq ($(DEBUG),1)
    CXXFLAGS = -g -O0 -Wall -fmax-errors=5 -fconcepts -std=c++17 -pthread
    CFLAGS += -g -O0
    LDFLAGS_DEBUG = -pthread -lperfstat  # Dynamic linking for easier debugging
else
    CXXFLAGS = -Wall -Werror -fmax-errors=5 -fconcepts -std=c++17 -pthread
endif

# Linking Flags - Static Build (default for production)
# This creates a standalone binary with no GNU library dependencies
# Only AIX system libraries (libperfstat, libc, etc.) are dynamically linked
# Benefits: Deploy to any AIX system without installing g++/libstdc++
ifeq ($(DEBUG),1)
    LDFLAGS = $(LDFLAGS_DEBUG)
else
    LDFLAGS = -pthread -static-libgcc -static-libstdc++ -lperfstat
endif

# Alternative: Dynamic linking (uncomment to use)
# LDFLAGS = -pthread -lperfstat

GIT_VERSION := $(shell git --no-pager describe --tags --always --long | sed "s/v\(.*\)-\([0-9]*\)-.*/\1.\2/")

# ============================================================================
# Build Targets
# ============================================================================

all: build/node_exporter_aix

# Debug build - includes symbols and disables optimization
debug:
	$(MAKE) DEBUG=1 clean
	$(MAKE) DEBUG=1

# Help target
help:
	@echo "node_exporter_aix Build Targets:"
	@echo "  make          - Build production binary (optimized, static)"
	@echo "  make debug    - Build debug binary (with -g -O0, dynamic)"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make run      - Build and run the exporter"
	@echo "  make bff      - Create AIX BFF package"
	@echo ""
	@echo "Debug build: make DEBUG=1"
	@echo "Custom compiler: make CXX=/path/to/g++"

build/node_exporter_aix: build/server.o build/collectors.o build/main.o build/mounts.o build/vmstat_v.o build/civetweb.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o build/node_exporter_aix build/server.o build/collectors.o build/main.o build/mounts.o build/vmstat_v.o build/civetweb.o

build/server.o: server.cpp node_exporter_aix.hpp
	$(CXX) $(CXXFLAGS) -lperfstat -I civetweb/include -c -o build/server.o server.cpp

build/main.o: main.cpp node_exporter_aix.hpp
	$(CXX) $(CXXFLAGS) -lperfstat -D PROG_VERSION="\"$(GIT_VERSION)\"" -c -o build/main.o main.cpp

build/mounts.o: mounts.cpp node_exporter_aix.hpp
	$(CXX) $(CXXFLAGS) -lperfstat -D PROG_VERSION="\"$(GIT_VERSION)\"" -c -o build/mounts.o mounts.cpp

build/vmstat_v.o: vmstat_v.cpp
	$(CXX) $(CXXFLAGS) -lperfstat -D PROG_VERSION="\"$(GIT_VERSION)\"" -c -o build/vmstat_v.o vmstat_v.cpp

build/collectors.o: collectors.cpp generated/diskpaths.cpp generated/diskadapters.cpp generated/memory_pages.cpp generated/memory.cpp generated/cpus.cpp generated/disks.cpp generated/netinterfaces.cpp generated/netadapters.cpp generated/netbuffers.cpp generated/partition.cpp generated/fcstats.cpp node_exporter_aix.hpp
	$(CXX) $(CXXFLAGS) -lperfstat -c -o build/collectors.o collectors.cpp

build/civetweb.o: civetweb/src/civetweb.c
	$(CC) $(CFLAGS) -I civetweb/include -DNO_SSL -DNO_FILES -c -o build/civetweb.o civetweb/src/civetweb.c

generated/%s.cpp: data_sources/%.multiple scripts/generate_multiple.ksh templates/generate_multiple.template
	ksh scripts/generate_multiple.ksh $* generated/$*s.cpp

generated/%.cpp: data_sources/%.total scripts/generate_total.ksh templates/generate_total.template
	ksh scripts/generate_total.ksh $* generated/$*.cpp

run: build/node_exporter_aix
	echo Starting
	build/node_exporter_aix

bff: clean build/node_exporter_aix
	sed "s/VERSION/$(GIT_VERSION)/; s%PWD%$(PWD)%;" bff_template > build/bff_template
	sudo rm -rf build/root
	mkdir -p build/root/usr/local/bin/
	cp build/node_exporter_aix build/root/usr/local/bin/
	sudo chown root.system build/root/usr/local/bin/node_exporter_aix
	sudo mkinstallp -d build/root -T build/bff_template
	cp build/root/tmp/node_exporter_aix.$(GIT_VERSION).bff build/

clean:
	sudo rm -rf build/* generated/*
