#ifndef JSXPOSEDX_MEMORY_TOOL_PROTOCOL_H
#define JSXPOSEDX_MEMORY_TOOL_PROTOCOL_H

#include <string>
#include <vector>

#include "memory_tool_session.h"

namespace memory_tool::protocol {

std::string SerializeMemoryRegions(const std::vector<MemoryRegion>& regions);

std::string SerializeSearchSessionState(const SearchSessionStateView& state);

std::string SerializeSearchTaskState(const SearchTaskStateView& state);

std::string SerializeSearchResults(const std::vector<SearchResultView>& results);

std::string SerializePointerScanSessionState(const PointerScanSessionStateView& state);

std::string SerializePointerScanTaskState(const PointerScanTaskStateView& state);

std::string SerializePointerScanResults(const std::vector<PointerScanResultEntry>& results);

std::string SerializeMemoryValuePreviews(const std::vector<MemoryValuePreview>& previews);

std::string SerializeFrozenMemoryValues(const std::vector<FrozenMemoryValueView>& values);

}  // namespace memory_tool::protocol

#endif  // JSXPOSEDX_MEMORY_TOOL_PROTOCOL_H
