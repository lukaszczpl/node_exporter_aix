# AI Context for node_exporter_aix

## Project Overview
`node_exporter_aix` is a Prometheus exporter for AIX hardware and OS metrics.
It is written in C++ (C++17) and uses the native `libperfstat` library on AIX.

## Architecture
- **Language**: C++17
- **Build System**: GNU Make
- **Compiler**: GCC (g++) from AIX Toolbox
- **Libraries**:
  - `libperfstat`: AIX standard library for performance statistics.
  - `asio` (Standalone): For networking and async I/O.
  - `Simple-Web-Server`: Embedded HTTP server.

### Directory Structure
- `data_sources/`: Definitions for metric sources.
- `generated/`: Code generated from data sources.
- `scripts/`: Helper scripts for code generation (`generate_multiple.ksh`, `generate_total.ksh`).
- `templates/`: Templates used by generation scripts.
- `build/`: Output directory for binaries and object files.

## Build Instructions
The project is built on AIX.

```sh
# Set PATH to include GNU Make and GCC if necessary
export PATH=/opt/freeware/bin:$PATH

# Initialize submodules (first time)
git submodule init
git submodule update

# Build
make
```

### Binary Location
The compiled binary is placed in `./build/node_exporter_aix`.

## Coding Standards
- **Standard**: C++17
- **Style**:
  - Indentation: Tabs for Makefiles (required), generally tabs or 4 spaces for C++.
  - Use `std::` namespace explicitly.
- **AIX Specifics**:
  - Uses `libperfstat` structures.
  - Linker flags: `-Wl,-bstatic -lstdc++ -lgcc -Wl,-bdynamic` to link libstdc++ statically (common practice on AIX to avoid runtime dependency issues).

## AI Agent Guidelines
- When adding new collectors, check `libperfstat.h` documentation or system headers.
- Remember specific AIX paths or commands (e.g., `installp`, `startsrc`) when dealing with deployment scripts.
