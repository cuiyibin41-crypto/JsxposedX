#ifndef JSXPOSEDX_MEMORY_TOOL_SESSION_H
#define JSXPOSEDX_MEMORY_TOOL_SESSION_H

#include <cstddef>
#include <cstdint>
#include <memory>
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

enum class SearchRuntimeMode : int {
    kStandard = 0,
    kXor = 1,
    kAuto = 2,
    kFuzzy = 3,
};

enum class FuzzyCompareMode : int {
    kUnknown = 0,
    kUnchanged = 1,
    kChanged = 2,
    kIncreased = 3,
    kDecreased = 4,
};

enum class BytesDisplayEncoding : int {
    kHex = 0,
    kUtf8 = 1,
    kUtf16Le = 2,
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
    SearchValueType matched_type = SearchValueType::kI32;
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

struct MemoryWriteRequest {
    uint64_t address = 0;
    SearchValue value;
};

struct MemoryFreezeRequest {
    uint64_t address = 0;
    SearchValue value;
    bool enabled = false;
};

struct FrozenMemoryValueView {
    int pid = 0;
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
    bool little_endian = true;
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

struct FuzzyCandidate {
    uint64_t address = 0;
    uint64_t region_start = 0;
    uint64_t previous_value_bits = 0;
};

struct FuzzyInitialRegion {
    uint64_t region_start = 0;
    size_t slot_count = 0;
    std::vector<uint8_t> snapshot_bytes;
};

struct SearchSession {
    bool has_active_session = false;
    int pid = 0;
    SearchValueType type = SearchValueType::kI32;
    SearchRuntimeMode mode = SearchRuntimeMode::kStandard;
    FuzzyCompareMode fuzzy_compare_mode = FuzzyCompareMode::kUnknown;
    bool exact_mode = true;
    bool little_endian = true;
    BytesDisplayEncoding bytes_display_encoding = BytesDisplayEncoding::kHex;
    size_t value_size = 0;
    std::vector<uint8_t> current_value_bytes;
    std::string current_display_value;
    std::vector<MemoryRegion> regions;
    std::shared_ptr<std::vector<FuzzyInitialRegion>> fuzzy_initial_regions;
    std::shared_ptr<std::vector<FuzzyCandidate>> fuzzy_candidates;
    std::vector<SearchResultEntry> results;

    void Clear();
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_SESSION_H
