#include "memory_tool_utils.h"

#include <array>
#include <cctype>
#include <cstdio>
#include <iomanip>
#include <sstream>
#include <string>

namespace memory_tool::utils {

std::string Trim(const std::string& value) {
    size_t start = 0;
    while (start < value.size() && std::isspace(static_cast<unsigned char>(value[start]))) {
        start++;
    }

    size_t end = value.size();
    while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1]))) {
        end--;
    }

    return value.substr(start, end - start);
}

std::string EscapeShellSingleQuotes(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size());
    for (char ch : value) {
        if (ch == '\'') {
            escaped += "'\"'\"'";
        } else {
            escaped += ch;
        }
    }
    return escaped;
}

std::string BuildGetPidCommand(const std::string& package_name) {
    return "ps -A | grep -F -- '" + EscapeShellSingleQuotes(package_name) +
           "' | awk '{print $2}' | head -n 1";
}

std::string WrapCommandWithSu(const std::string& command) {
    std::string escaped;
    escaped.reserve(command.size() * 2);

    for (char ch : command) {
        switch (ch) {
            case '\\':
                escaped += "\\\\";
                break;
            case '"':
                escaped += "\\\"";
                break;
            case '$':
                escaped += "\\$";
                break;
            case '`':
                escaped += "\\`";
                break;
            default:
                escaped += ch;
                break;
        }
    }

    return "su -c \"" + escaped + "\"";
}

bool ExecuteCommand(const std::string& command, std::string* output, int* exit_code) {
    if (output == nullptr || exit_code == nullptr) {
        return false;
    }

    std::array<char, 128> buffer{};
    output->clear();

    FILE* pipe = popen(command.c_str(), "r");
    if (pipe == nullptr) {
        *exit_code = -1;
        return false;
    }

    while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
        output->append(buffer.data());
    }

    *exit_code = pclose(pipe);
    return true;
}

jlong ParsePid(const std::string& output) {
    const std::string trimmed = Trim(output);
    if (trimmed.empty()) {
        return 0L;
    }

    try {
        return static_cast<jlong>(std::stoll(trimmed));
    } catch (...) {
        return 0L;
    }
}

std::string HexEncode(const std::vector<uint8_t>& bytes) {
    std::ostringstream stream;
    for (uint8_t byte : bytes) {
        stream << std::hex << std::setw(2) << std::setfill('0')
               << static_cast<int>(byte);
    }
    return stream.str();
}

std::string JsonEscape(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size() * 2);
    for (unsigned char ch : value) {
        switch (ch) {
            case '\\':
                escaped += "\\\\";
                break;
            case '"':
                escaped += "\\\"";
                break;
            case '\n':
                escaped += "\\n";
                break;
            case '\r':
                escaped += "\\r";
                break;
            case '\t':
                escaped += "\\t";
                break;
            case '\b':
                escaped += "\\b";
                break;
            case '\f':
                escaped += "\\f";
                break;
            default:
                if (ch < 0x20) {
                    std::ostringstream control_stream;
                    control_stream << "\\u"
                                   << std::hex
                                   << std::nouppercase
                                   << std::setw(4)
                                   << std::setfill('0')
                                   << static_cast<int>(ch);
                    escaped += control_stream.str();
                } else {
                    escaped += static_cast<char>(ch);
                }
                break;
        }
    }
    return escaped;
}

}  // namespace memory_tool::utils
