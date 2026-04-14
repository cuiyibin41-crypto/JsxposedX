#ifndef JSXPOSEDX_MEMORY_TOOL_SESSION_H
#define JSXPOSEDX_MEMORY_TOOL_SESSION_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace memory_tool {

enum class SearchValueType : int {
    kI8 = 0,
    kI16 = 1,
    kI32 = 2,
    kI64 = 3,
    kF32 = 4,
    kF64 = 5,
    kBytes = 6,
};

enum class SearchMatchMode : int {
    kExact = 0,
};

enum class SearchTaskStatus : int {
    kIdle = 0,
    kRunning = 1,
    kCompleted = 2,
    kCancelled = 3,
    kFailed = 4,
};

struct SearchValue {
    SearchValueType type = SearchValueType::kI32;
    std::string text_value;
    std::vector<uint8_t> bytes_value;
    bool little_endian = true;
};

struct MemoryRegion {
    uint64_t start_address = 0;
    uint64_t end_address = 0;
    std::string perms;
    uint64_t size = 0;
    std::string path;
    bool is_anonymous = false;
};

struct SearchResultEntry {
    uint64_t address = 0;
    uint64_t region_start = 0;
};

struct SearchResultView {
    uint64_t address = 0;
    uint64_t region_start = 0;
    std::string region_type_key;
    SearchValueType type = SearchValueType::kI32;
    std::vector<uint8_t> raw_bytes;
    std::string display_value;
};

struct MemoryReadRequest {
    uint64_t address = 0;
    SearchValueType type = SearchValueType::kI32;
    size_t length = 0;
};

struct MemoryValuePreview {
    uint64_t address = 0;
    SearchValueType type = SearchValueType::kI32;
    std::vector<uint8_t> raw_bytes;
    std::string display_value;
};

struct SearchSessionStateView {
    bool has_active_session = false;
    int pid = 0;
    SearchValueType type = SearchValueType::kI32;
    size_t region_count = 0;
    size_t result_count = 0;
    bool exact_mode = true;
};

struct SearchTaskStateView {
    SearchTaskStatus status = SearchTaskStatus::kIdle;
    bool is_first_scan = true;
    int pid = 0;
    size_t processed_region_count = 0;
    size_t total_region_count = 0;
    size_t processed_entry_count = 0;
    size_t total_entry_count = 0;
    uint64_t processed_byte_count = 0;
    uint64_t total_byte_count = 0;
    size_t result_count = 0;
    uint64_t elapsed_milliseconds = 0;
    bool can_cancel = false;
    std::string message;
};

struct SearchSession {
    bool has_active_session = false;
    int pid = 0;
    SearchValueType type = SearchValueType::kI32;
    bool exact_mode = true;
    bool little_endian = true;
    bool bytes_display_as_text = false;
    size_t value_size = 0;
    std::vector<uint8_t> current_value_bytes;
    std::string current_display_value;
    std::vector<MemoryRegion> regions;
    std::vector<SearchResultEntry> results;

    void Clear();
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_SESSION_H
