#include "memory_tool_protocol.h"

#include <sstream>

#include "memory_tool_utils.h"

namespace memory_tool::protocol {

namespace {

const char* ToJsonBool(bool value) {
    return value ? "true" : "false";
}

int ToRawType(SearchValueType type) {
    return static_cast<int>(type);
}

int ToRawTaskStatus(SearchTaskStatus status) {
    return static_cast<int>(status);
}

}  // namespace

std::string SerializeMemoryRegions(const std::vector<MemoryRegion>& regions) {
    std::ostringstream stream;
    stream << '[';
    for (size_t index = 0; index < regions.size(); ++index) {
        const MemoryRegion& region = regions[index];
        if (index > 0) {
            stream << ',';
        }
        stream << '{'
               << "\"startAddress\":" << region.start_address << ','
               << "\"endAddress\":" << region.end_address << ','
               << "\"perms\":\"" << utils::JsonEscape(region.perms) << "\","
               << "\"size\":" << region.size << ','
               << "\"path\":\"" << utils::JsonEscape(region.path) << "\","
               << "\"isAnonymous\":" << ToJsonBool(region.is_anonymous)
               << '}';
    }
    stream << ']';
    return stream.str();
}

std::string SerializeSearchSessionState(const SearchSessionStateView& state) {
    std::ostringstream stream;
    stream << '{'
           << "\"hasActiveSession\":" << ToJsonBool(state.has_active_session) << ','
           << "\"pid\":" << state.pid << ','
           << "\"type\":" << ToRawType(state.type) << ','
           << "\"regionCount\":" << state.region_count << ','
           << "\"resultCount\":" << state.result_count << ','
           << "\"exactMode\":" << ToJsonBool(state.exact_mode)
           << '}';
    return stream.str();
}

std::string SerializeSearchTaskState(const SearchTaskStateView& state) {
    std::ostringstream stream;
    stream << '{'
           << "\"status\":" << ToRawTaskStatus(state.status) << ','
           << "\"isFirstScan\":" << ToJsonBool(state.is_first_scan) << ','
           << "\"pid\":" << state.pid << ','
           << "\"processedRegions\":" << state.processed_region_count << ','
           << "\"totalRegions\":" << state.total_region_count << ','
           << "\"processedEntries\":" << state.processed_entry_count << ','
           << "\"totalEntries\":" << state.total_entry_count << ','
           << "\"processedBytes\":" << state.processed_byte_count << ','
           << "\"totalBytes\":" << state.total_byte_count << ','
           << "\"resultCount\":" << state.result_count << ','
           << "\"elapsedMilliseconds\":" << state.elapsed_milliseconds << ','
           << "\"canCancel\":" << ToJsonBool(state.can_cancel) << ','
           << "\"message\":\"" << utils::JsonEscape(state.message) << "\""
           << '}';
    return stream.str();
}

std::string SerializeSearchResults(const std::vector<SearchResultView>& results) {
    std::ostringstream stream;
    stream << '[';
    for (size_t index = 0; index < results.size(); ++index) {
        const SearchResultView& result = results[index];
        if (index > 0) {
            stream << ',';
        }
        stream << '{'
               << "\"address\":" << result.address << ','
               << "\"regionStart\":" << result.region_start << ','
               << "\"type\":" << ToRawType(result.type) << ','
               << "\"rawBytesHex\":\"" << utils::HexEncode(result.raw_bytes) << "\","
               << "\"displayValue\":\"" << utils::JsonEscape(result.display_value) << "\""
               << '}';
    }
    stream << ']';
    return stream.str();
}

std::string SerializeMemoryValuePreviews(const std::vector<MemoryValuePreview>& previews) {
    std::ostringstream stream;
    stream << '[';
    for (size_t index = 0; index < previews.size(); ++index) {
        const MemoryValuePreview& preview = previews[index];
        if (index > 0) {
            stream << ',';
        }
        stream << '{'
               << "\"address\":" << preview.address << ','
               << "\"type\":" << ToRawType(preview.type) << ','
               << "\"rawBytesHex\":\"" << utils::HexEncode(preview.raw_bytes) << "\","
               << "\"displayValue\":\"" << utils::JsonEscape(preview.display_value) << "\""
               << '}';
    }
    stream << ']';
    return stream.str();
}

}  // namespace memory_tool::protocol
