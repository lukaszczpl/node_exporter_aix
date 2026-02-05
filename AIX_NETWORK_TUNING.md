# AIX Network Tuning for Node Exporter

## Problem

Large HTTP responses may be truncated on AIX due to default socket buffer sizes.

## Error Symptoms

```
curl: (18) end of response with 375218 bytes missing
curl: transfer closed with outstanding read data remaining
```

## Root Cause

AIX default `tcp_sendspace` is only 32KB (32767 bytes), which can cause truncation of large metric responses.

## Solution

### Option 1: Increase AIX Socket Buffers (Recommended)

Run as root:

```bash
# Increase TCP send buffer to 256KB
no -p -o tcp_sendspace=262144

# Increase TCP receive buffer to 256KB  
no -p -o tcp_recvspace=262144

# Increase max socket buffer to 512KB
no -p -o sb_max=524288

# Enable RFC1323 for window scaling (required for buffers > 64KB)
no -p -o rfc1323=1
```

**Note**: Changes with `-p` are persistent across reboots.

### Option 2: Verify Current Settings

```bash
# Check current values
no -o tcp_sendspace
no -o tcp_recvspace
no -o sb_max
no -o rfc1323
```

### Option 3: Temporary Change (No Reboot)

```bash
# Non-persistent change
no -o tcp_sendspace=262144
no -o tcp_recvspace=262144
no -o sb_max=524288
no -o rfc1323=1
```

## Application-Level Fix

The application now uses CivetWeb's chunked transfer encoding which sends data in 8KB chunks. This should work even with default AIX settings, but for best performance and reliability, the system tuning above is recommended.

## Verification

After applying the fix:

```bash
./build/node_exporter_aix
curl http://localhost:9100/metrics > metrics.txt
echo $?  # Should return 0

# Check file size
ls -la metrics.txt
wc -l metrics.txt
```

## References

- IBM AIX TCP/IP Tuning Guide
- CivetWeb Chunked Transfer Documentation
