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

}  // namespace memory_tool
