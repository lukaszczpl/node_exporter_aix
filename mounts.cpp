#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <sys/mntctl.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <sys/vmount.h>
#include <vector>

#include "node_exporter_aix.hpp"

std::vector<mountpoint> list_mounts() {
  std::vector<mountpoint> output;

  int buffer_size = 4096; // Start with reasonable size
  int rc = 0;
  char *buffer = nullptr;

  // Retry with larger buffer if needed
  for (int attempts = 0; attempts < 3; attempts++) {
    buffer = (char *)malloc(buffer_size);
    if (!buffer) {
      perror("Error allocating buffer for mntctl");
      return output; // Return empty vector instead of exit
    }

    memset(buffer, 0, buffer_size);
    rc = mntctl(MCTL_QUERY, buffer_size, buffer);

    if (rc > 0) {
      break; // Success
    } else if (rc == 0) {
      // Buffer too small, double it
      free(buffer);
      buffer = nullptr;
      buffer_size *= 2;
    } else {
      // Error
      perror("Error calling mntctl");
      free(buffer);
      return output; // Return empty vector instead of exit
    }
  }

  if (rc <= 0) {
    if (buffer)
      free(buffer);
    return output;
  }

  struct vmount *mounts;
  char *current = buffer;

  for (int i = 0; i < rc; i++) {
    mounts = (struct vmount *)current;

    if (mounts->vmt_gfstype == MNT_J2 || mounts->vmt_gfstype == MNT_JFS) {
      if (vmt2datasize(mounts, VMT_STUB) && vmt2datasize(mounts, VMT_OBJECT)) {
        struct mountpoint mp;
        mp.device = vmt2dataptr(mounts, VMT_OBJECT);
        mp.mountpoint = vmt2dataptr(mounts, VMT_STUB);

        if (mounts->vmt_gfstype == MNT_J2) {
          mp.fstype = "jfs2";
        } else if (mounts->vmt_gfstype == MNT_JFS) {
          mp.fstype = "jfs";
        } else {
          mp.fstype = "unknown";
        }

        output.push_back(mp);
      }
    }

    current = current + mounts->vmt_length;
  }
  free(buffer);

  return output;
}

std::vector<filesystem> stat_filesystems(std::vector<mountpoint> mounts) {
  std::vector<filesystem> output;

  for (auto it = mounts.begin(); it != mounts.end(); it++) {
    struct statvfs64 s;
    int rc = statvfs64((*it).mountpoint.c_str(), &s);

    if (rc < 0) {
      perror("Error getting statvfs64");
      continue; // Skip this mount instead of exiting
    }

    struct filesystem fs;
    fs.mountpoint = (*it).mountpoint;
    fs.device = (*it).device;
    fs.fstype = (*it).fstype;
    fs.avail_bytes = s.f_bavail * s.f_bsize;
    fs.size_bytes = s.f_blocks * s.f_bsize;
    fs.free_bytes = s.f_bfree * s.f_bsize;
    fs.files = s.f_files;
    fs.files_free = s.f_ffree;
    fs.files_avail = s.f_favail;

    output.push_back(fs);
  }

  return output;
}

#ifdef TESTING
int main() {
  auto fs = stat_filesystems(list_mounts());

  for (auto it = fs.begin(); it != fs.end(); it++) {
    std::cout << (*it).mountpoint << " " << (*it).fstype << " "
              << (*it).size_bytes / 1024 << " " << (*it).free_bytes / 1024
              << std::endl;
  }

  return 0;
}
#endif
