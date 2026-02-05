#include <cstdio>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <array>
#include <sstream>
#include <algorithm>

#include "node_exporter_aix.hpp"

// Execute external command and return output
std::string exec_lspath(const char* cmd) {
    std::array<char, 2048> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

void gather_mpio(std::ostream& response, const std::string& static_labels) {
    static const std::string WHITESPACE = " \n\r\t\f\v";
    
    std::string output;
    try {
        output = exec_lspath("lspath");
    } catch (const std::exception& e) {
        std::cerr << "Error executing lspath: " << e.what() << std::endl;
        return;
    }

    // Output Prometheus metric header
    response << "# HELP aix_mpio_path_status MPIO path status (1=path exists, 0=path failed)" << std::endl;
    response << "# TYPE aix_mpio_path_status gauge" << std::endl;

    std::stringstream ss(output);
    std::string line;

    while(std::getline(ss, line, '\n')) {
        // Trim leading/trailing whitespace
        size_t start = line.find_first_not_of(WHITESPACE);
        if (start == std::string::npos) continue; // Empty line
        
        size_t end = line.find_last_not_of(WHITESPACE);
        line = line.substr(start, end - start + 1);

        // Parse line: "Status Device Adapter"
        // Example: "Enabled hdisk2 fscsi0"
        std::istringstream iss(line);
        std::string status, device, adapter;
        
        if (!(iss >> status >> device >> adapter)) {
            // Malformed line, skip
            continue;
        }

        // Determine metric value based on status
        int value = 0;
        if (status == "Enabled") {
            value = 1;
        } else if (status == "Failed" || status == "Disabled" || status == "Missing" || status == "Defined") {
            value = 0;
        } else {
            // Unknown status, log and skip
            std::cerr << "Unknown MPIO path status: " << status << std::endl;
            continue;
        }

        // Output metric with labels
        response << "aix_mpio_path_status{device=\"" << device 
                 << "\",adapter=\"" << adapter 
                 << "\",status=\"" << status << "\"," 
                 << static_labels << "} " << value << std::endl;
    }
}
