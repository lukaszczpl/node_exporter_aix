#include <chrono>
#include <map>
#include <string>
#include <thread>
#include <sstream>
#include <iostream>
#include <vector>
#include <cstring>
#include <unistd.h>

#include "civetweb.h"
#include "node_exporter_aix.hpp"

static int request_handler(struct mg_connection *conn, void *cbdata) {
	int flags = *(int*)cbdata;
	std::ostringstream output;

	auto static_labels = generate_static_labels();

	if(flags & PART_COMPAT)       gather_cpu_compat(output, static_labels);
	if(flags & PART_COMPAT)       gather_cpus_compat(output, static_labels);
	if(flags & PART_CPU)          gather_cpus(output, static_labels);
	if(flags & PART_DISKADAPTER)  gather_diskadapters(output, static_labels);
	if(flags & PART_DISKPATH)     gather_diskpaths(output, static_labels);
	if(flags & PART_MEM_PAGES)    gather_memory_pages(output, static_labels);
	if(flags & PART_MEM)          gather_memory(output, static_labels);
	if(flags & PART_DISK)         gather_disks(output, static_labels);
	if(flags & PART_NETINTERFACE) gather_netinterfaces(output, static_labels);
	if(flags & PART_NETADAPTER)   gather_netadapters(output, static_labels);
	if(flags & PART_NETBUFFER)    gather_netbuffers(output, static_labels);
	if(flags & PART_PARTITION)    gather_partition(output, static_labels);
	if(flags & PART_FILESYSTEMS)  gather_filesystems(output, static_labels);
	if(flags & PART_VMSTAT_V)     gather_vmstat_v(output, static_labels);
	if(flags & PART_FCSTAT_E)     gather_fcstats(output, static_labels);

	std::string s = output.str();
	mg_printf(conn,
		"HTTP/1.1 200 OK\r\n"
		"Content-Type: text/plain; version=0.0.4\r\n"
		"Content-Length: %lu\r\n"
		"\r\n",
		(unsigned long)s.length());
	
	mg_write(conn, s.c_str(), s.length());

	return 200;
}

int start_server(int port, int flags) {
	std::string port_str = std::to_string(port);
	const char *options[] = {
		"listening_ports", port_str.c_str(),
		"num_threads", "5",
		NULL
	};

	struct mg_callbacks callbacks;
	memset(&callbacks, 0, sizeof(callbacks));

	struct mg_context *ctx;
	// Initialize CivetWeb
	// We pass &flags as user_data, but effectively we use it in the handler registration
	ctx = mg_start(&callbacks, NULL, options);
	
	if (!ctx) {
		std::cerr << "Failed to start CivetWeb on port " << port << std::endl;
		return 1;
	}

	// Handler for /metrics (and root / for simplicity as per original behavior which seemed to handle everything?)
	// Original code: server.default_resource["GET"]... so it handled everything.
	mg_set_request_handler(ctx, "/", request_handler, &flags);

	std::cout << "Node exporter started on port " << port << std::endl;

	// Loop forever to keep the server handling requests
	while(1) {
		sleep(10);
	}

	mg_stop(ctx);

	return 0;
}
