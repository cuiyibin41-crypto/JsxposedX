#include "memory_tool_session.h"

namespace memory_tool {

void SearchSession::Clear() {
    has_active_session = false;
    pid = 0;
    type = SearchValueType::kI32;
    exact_mode = true;
    little_endian = true;
    bytes_display_as_text = false;
    value_size = 0;
    current_value_bytes.clear();
    current_display_value.clear();
    regions.clear();
    results.clear();
}

}  // namespace memory_tool
