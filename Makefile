# ============================================================================
# node_exporter_aix Build Configuration
# ============================================================================

# Compiler Configuration
# Recommended: g++ 9.x or newer for full C++17 support
# Override with: make CXX=/path/to/your/g++
CXX ?= g++
CC ?= gcc

# Compilation Flags
CXXFLAGS = -Wall -Werror -fmax-errors=5 -fconcepts -std=c++17 -pthread

# Linking Flags - Static Build (default)
# This creates a standalone binary with no GNU library dependencies
# Only AIX system libraries (libperfstat, libc, etc.) are dynamically linked
# Benefits: Deploy to any AIX system without installing g++/libstdc++
LDFLAGS = -pthread -static-libgcc -static-libstdc++ -lperfstat

# Alternative: Dynamic linking (uncomment to use)
# LDFLAGS = -pthread -lperfstat

GIT_VERSION := $(shell git --no-pager describe --tags --always --long | sed "s/v\(.*\)-\([0-9]*\)-.*/\1.\2/")

all: build/node_exporter_aix

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
	$(CC) -I civetweb/include -DNO_SSL -DNO_FILES -c -o build/civetweb.o civetweb/src/civetweb.c

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
