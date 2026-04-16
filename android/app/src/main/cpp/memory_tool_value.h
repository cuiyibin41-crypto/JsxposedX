#ifndef JSXPOSEDX_MEMORY_TOOL_VALUE_H
#define JSXPOSEDX_MEMORY_TOOL_VALUE_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "memory_tool_scanner.h"
#include "memory_tool_session.h"

namespace memory_tool {

enum class SpecialSearchMode : int {
    kNone = 0,
    kXor = 1,
    kAuto = 2,
    kFuzzy = 3,
};

struct AutoSearchPlan {
    std::vector<SearchPatternVariant> variants;
    std::string display_value;
};

size_t ResolveValueByteLength(SearchValueType type, size_t requested_length);

SpecialSearchMode ResolveSpecialSearchMode(const SearchValue& value);

bool BuildSearchPattern(const SearchValue& value,
                        std::vector<uint8_t>* bytes,
                        std::string* error);

bool ParseXorTargetValue(const SearchValue& value,
                         uint32_t* target_value,
                         std::string* display_value,
                         std::string* error);

bool ParseFuzzyCompareMode(const SearchValue& value,
                           FuzzyCompareMode* compare_mode,
                           std::string* display_value,
                           std::string* error);

bool BuildAutoSearchPlan(const SearchValue& value,
                         AutoSearchPlan* plan,
                         std::string* error);

BytesDisplayEncoding ResolveBytesDisplayEncoding(const SearchValue& value);

std::string FormatDisplayValue(SearchValueType type,
                               const std::vector<uint8_t>& raw_bytes,
                               bool little_endian,
                               BytesDisplayEncoding bytes_display_encoding =
                                   BytesDisplayEncoding::kHex);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_VALUE_H
