# AIX Tuning Guide for node_exporter_aix

This document provides recommended AIX kernel parameter tuning for optimal performance of `node_exporter_aix`.

## Overview

The `node_exporter_aix` application uses several AIX system calls that interact with kernel limits and tunables. Proper configuration ensures stability, especially on large systems with many CPUs, mount points, or high request rates.

## Memory and Process Limits

### maxuproc
- **Description**: Maximum number of processes per user
- **Recommendation**: At least 200 for the exporter user
- **Command**: `chdev -l sys0 -a maxuproc=200`
- **Why**: The exporter may spawn subprocesses (e.g., for `vmstat -v`)

### maxperm / minperm
- **Description**: Memory tuning parameters for file cache
- **Default**: Usually adequate (maxperm=80%, minperm=20%)
- **Consideration**: On systems with many mount points, filesystem stats may increase cache pressure

### maxvgs
- **Description**: Maximum number of volume groups
- **Default**: 1024
- **Impact**: Systems with many VGs will have many mount points. The exporter now uses dynamic buffer allocation to handle this.

## Process and System Limits

### ncargs
- **Description**: Maximum size of arguments to exec()
- **Default**: 24576 (24KB) on AIX 7.2
- **Impact**: Used when calling `vmstat -v` via popen()
- **Recommendation**: Default is sufficient

## Network Tuning (for HTTP Server)

### rfc1323
- **Description**: TCP window scaling
- **Recommendation**: Enable if not already (`no -p -o rfc1323=1`)
- **Why**: Improves HTTP response performance for large metric payloads

### tcp_sendspace / tcp_recvspace
- **Description**: TCP buffer sizes
- **Default**: 262144 (256KB)
- **Recommendation**: Increase to 524288 if serving many concurrent clients
- **Command**: `no -p -o tcp_sendspace=524288 tcp_recvspace=524288`

## Specific to node_exporter

### CivetWeb Thread Pool
- **Configuration**: `num_threads=5` (hardcoded in server.cpp)
- **Tuning**: For high-concurrency environments, consider increasing to 10-20
- **Location**: Edit `server.cpp` line containing `"num_threads"`

### perfstat Considerations
- The exporter calls `perfstat_cpu()`, `perfstat_disk()`, etc. without pagination
- On systems with >100 CPUs or >100 disks, memory usage can spike
- **Monitor**: Use `svmon -P <pid>` to check exporter memory usage

## Verification

After tuning, verify settings:
```bash
lsattr -El sys0 | grep maxuproc
no -a | grep tcp_sendspace
no -a | grep rfc1323
```

## Graceful Shutdown

The exporter now handles SIGTERM and SIGINT properly. To stop:
```bash
kill -TERM <pid>
# or
stopsrc -s node_exporter_aix
```

The server will output "Shutting down gracefully..." and cleanly release resources.
