#include "memory_tool_session.h"

namespace memory_tool {

void SearchSession::Clear() {
    has_active_session = false;
    pid = 0;
    type = SearchValueType::kI32;
    mode = SearchRuntimeMode::kStandard;
    fuzzy_compare_mode = FuzzyCompareMode::kUnknown;
    exact_mode = true;
    little_endian = true;
    bytes_display_encoding = BytesDisplayEncoding::kHex;
    value_size = 0;
    current_value_bytes.clear();
    current_display_value.clear();
    regions.clear();
    fuzzy_initial_regions.reset();
    fuzzy_candidates.reset();
    results.clear();
}

void PointerScanSession::Clear() {
    has_active_session = false;
    pid = 0;
    target_address = 0;
    pointer_width = 0;
    max_offset = 0;
    alignment = 0;
    regions.clear();
    results.clear();
}

}  // namespace memory_tool
