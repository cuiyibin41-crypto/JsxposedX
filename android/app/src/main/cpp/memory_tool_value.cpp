#include "memory_tool_value.h"

#include <algorithm>
#include <cmath>
#include <codecvt>
#include <cstring>
#include <iomanip>
#include <limits>
#include <locale>
#include <sstream>
#include <stdexcept>

namespace memory_tool {

namespace {

constexpr char kXorPrefix[] = "__jsx_xor__:";
constexpr char kAutoPrefix[] = "__jsx_auto__:";
constexpr char kFuzzyPrefix[] = "__jsx_fuzzy__:";

template <typename T>
std::vector<uint8_t> EncodeBytes(T value, bool little_endian) {
    std::vector<uint8_t> bytes(sizeof(T));
    std::memcpy(bytes.data(), &value, sizeof(T));
    const bool host_little_endian = [] {
        uint16_t sample = 0x1;
        return *reinterpret_cast<uint8_t*>(&sample) == 0x1;
    }();
    if (host_little_endian != little_endian) {
        std::reverse(bytes.begin(), bytes.end());
    }
    return bytes;
}

template <typename T>
T DecodeBytes(const std::vector<uint8_t>& raw_bytes, bool little_endian) {
    std::vector<uint8_t> copy = raw_bytes;
    const bool host_little_endian = [] {
        uint16_t sample = 0x1;
        return *reinterpret_cast<uint8_t*>(&sample) == 0x1;
    }();
    if (host_little_endian != little_endian) {
        std::reverse(copy.begin(), copy.end());
    }

    T value{};
    std::memcpy(&value, copy.data(), sizeof(T));
    return value;
}

std::string FormatHex(const std::vector<uint8_t>& bytes) {
    std::ostringstream stream;
    for (size_t index = 0; index < bytes.size(); ++index) {
        if (index > 0) {
            stream << ' ';
        }
        stream << std::uppercase << std::hex << std::setw(2) << std::setfill('0')
               << static_cast<int>(bytes[index]);
    }
    return stream.str();
}

std::string FormatUtf8Text(const std::vector<uint8_t>& bytes) {
    return std::string(bytes.begin(), bytes.end());
}

std::string FormatUtf16LeText(const std::vector<uint8_t>& bytes) {
    if (bytes.empty()) {
        return {};
    }
    if (bytes.size() % 2 != 0) {
        return FormatHex(bytes);
    }

    std::u16string text;
    text.reserve(bytes.size() / 2);
    for (size_t index = 0; index < bytes.size(); index += 2) {
        const uint16_t code_unit = static_cast<uint16_t>(bytes[index]) |
                                   (static_cast<uint16_t>(bytes[index + 1]) << 8);
        text.push_back(static_cast<char16_t>(code_unit));
    }

    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter;
    return converter.to_bytes(text);
}

bool HasPrefix(const std::string& value, const char* prefix) {
    return value.rfind(prefix, 0) == 0;
}

std::string StripPrefix(const std::string& value, const char* prefix) {
    if (!HasPrefix(value, prefix)) {
        return value;
    }
    return value.substr(std::char_traits<char>::length(prefix));
}

template <typename T>
void AppendVariant(std::vector<SearchPatternVariant>* variants,
                   SearchValueType type,
                   T value,
                   bool little_endian) {
    if (variants == nullptr) {
        return;
    }
    SearchPatternVariant variant;
    variant.type = type;
    variant.pattern = EncodeBytes<T>(value, little_endian);
    variants->push_back(std::move(variant));
}

bool LooksLikeDecimalNumber(const std::string& value) {
    return value.find('.') != std::string::npos ||
           value.find('e') != std::string::npos ||
           value.find('E') != std::string::npos;
}

}  // namespace

size_t ResolveValueByteLength(SearchValueType type, size_t requested_length) {
    switch (type) {
        case SearchValueType::kI8:
            return 1;
        case SearchValueType::kI16:
            return 2;
        case SearchValueType::kI32:
            return 4;
        case SearchValueType::kI64:
            return 8;
        case SearchValueType::kF32:
            return 4;
        case SearchValueType::kF64:
            return 8;
        case SearchValueType::kBytes:
            return requested_length;
    }
    return requested_length;
}

SpecialSearchMode ResolveSpecialSearchMode(const SearchValue& value) {
    if (HasPrefix(value.text_value, kXorPrefix)) {
        return SpecialSearchMode::kXor;
    }
    if (HasPrefix(value.text_value, kAutoPrefix)) {
        return SpecialSearchMode::kAuto;
    }
    if (HasPrefix(value.text_value, kFuzzyPrefix)) {
        return SpecialSearchMode::kFuzzy;
    }
    return SpecialSearchMode::kNone;
}

bool BuildSearchPattern(const SearchValue& value,
                        std::vector<uint8_t>* bytes,
                        std::string* error) {
    if (bytes == nullptr) {
        return false;
    }

    bytes->clear();
    try {
        const std::string raw_value =
            HasPrefix(value.text_value, kFuzzyPrefix)
                ? StripPrefix(value.text_value, kFuzzyPrefix)
                : value.text_value;
        switch (value.type) {
            case SearchValueType::kI8:
                *bytes = EncodeBytes(static_cast<int8_t>(std::stoi(raw_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kI16:
                *bytes = EncodeBytes(static_cast<int16_t>(std::stoi(raw_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kI32:
                *bytes = EncodeBytes(static_cast<int32_t>(std::stol(raw_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kI64:
                *bytes = EncodeBytes(static_cast<int64_t>(std::stoll(raw_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kF32:
                *bytes = EncodeBytes(static_cast<float>(std::stof(raw_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kF64:
                *bytes = EncodeBytes(static_cast<double>(std::stod(raw_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kBytes:
                if (value.bytes_value.empty()) {
                    if (error != nullptr) {
                        *error = "Byte pattern is empty.";
                    }
                    return false;
                }
                *bytes = value.bytes_value;
                return true;
        }
    } catch (const std::exception& exception) {
        if (error != nullptr) {
            *error = exception.what();
        }
        return false;
    }

    if (error != nullptr) {
        *error = "Unsupported search value type.";
    }
    return false;
}

bool ParseXorTargetValue(const SearchValue& value,
                         uint32_t* target_value,
                         std::string* display_value,
                         std::string* error) {
    if (target_value == nullptr) {
        return false;
    }

    try {
        const std::string raw_value = StripPrefix(value.text_value, kXorPrefix);
        const unsigned long long parsed = std::stoull(raw_value);
        if (parsed > static_cast<unsigned long long>(std::numeric_limits<uint32_t>::max())) {
            if (error != nullptr) {
                *error = "XOR value is out of range.";
            }
            return false;
        }
        *target_value = static_cast<uint32_t>(parsed);
        if (display_value != nullptr) {
            *display_value = raw_value;
        }
        return true;
    } catch (const std::exception& exception) {
        if (error != nullptr) {
            *error = exception.what();
        }
        return false;
    }
}

bool ParseFuzzyCompareMode(const SearchValue& value,
                           FuzzyCompareMode* compare_mode,
                           std::string* display_value,
                           std::string* error) {
    if (compare_mode == nullptr) {
        return false;
    }

    const std::string raw_value = StripPrefix(value.text_value, kFuzzyPrefix);
    if (raw_value == "unknown") {
        *compare_mode = FuzzyCompareMode::kUnknown;
    } else if (raw_value == "unchanged") {
        *compare_mode = FuzzyCompareMode::kUnchanged;
    } else if (raw_value == "changed") {
        *compare_mode = FuzzyCompareMode::kChanged;
    } else if (raw_value == "increased") {
        *compare_mode = FuzzyCompareMode::kIncreased;
    } else if (raw_value == "decreased") {
        *compare_mode = FuzzyCompareMode::kDecreased;
    } else {
        if (error != nullptr) {
            *error = "Unsupported fuzzy compare mode.";
        }
        return false;
    }

    if (display_value != nullptr) {
        *display_value = raw_value;
    }
    return true;
}

bool BuildAutoSearchPlan(const SearchValue& value,
                         AutoSearchPlan* plan,
                         std::string* error) {
    if (plan == nullptr) {
        return false;
    }

    plan->variants.clear();
    plan->display_value.clear();
    try {
        const std::string raw_value = StripPrefix(value.text_value, kAutoPrefix);
        plan->display_value = raw_value;

        if (LooksLikeDecimalNumber(raw_value)) {
            const double parsed = std::stod(raw_value);
            AppendVariant<float>(&plan->variants,
                                 SearchValueType::kF32,
                                 static_cast<float>(parsed),
                                 value.little_endian);
            AppendVariant<double>(&plan->variants,
                                  SearchValueType::kF64,
                                  parsed,
                                  value.little_endian);
            return !plan->variants.empty();
        }

        const long long parsed_integer = std::stoll(raw_value);
        if (parsed_integer >= static_cast<long long>(std::numeric_limits<int32_t>::min()) &&
            parsed_integer <= static_cast<long long>(std::numeric_limits<int32_t>::max())) {
            AppendVariant<int32_t>(&plan->variants,
                                   SearchValueType::kI32,
                                   static_cast<int32_t>(parsed_integer),
                                   value.little_endian);
        }

        const double as_double = static_cast<double>(parsed_integer);
        const float as_float = static_cast<float>(parsed_integer);
        if (std::isfinite(as_float) &&
            static_cast<long long>(std::llround(static_cast<double>(as_float))) == parsed_integer) {
            AppendVariant<float>(&plan->variants,
                                 SearchValueType::kF32,
                                 as_float,
                                 value.little_endian);
        }

        AppendVariant<int64_t>(&plan->variants,
                               SearchValueType::kI64,
                               static_cast<int64_t>(parsed_integer),
                               value.little_endian);
        if (std::isfinite(as_double) &&
            static_cast<long long>(std::llround(as_double)) == parsed_integer) {
            AppendVariant<double>(&plan->variants,
                                  SearchValueType::kF64,
                                  as_double,
                                  value.little_endian);
        }
        if (parsed_integer >= static_cast<long long>(std::numeric_limits<int16_t>::min()) &&
            parsed_integer <= static_cast<long long>(std::numeric_limits<int16_t>::max())) {
            AppendVariant<int16_t>(&plan->variants,
                                   SearchValueType::kI16,
                                   static_cast<int16_t>(parsed_integer),
                                   value.little_endian);
        }
        if (parsed_integer >= static_cast<long long>(std::numeric_limits<int8_t>::min()) &&
            parsed_integer <= static_cast<long long>(std::numeric_limits<int8_t>::max())) {
            AppendVariant<int8_t>(&plan->variants,
                                  SearchValueType::kI8,
                                  static_cast<int8_t>(parsed_integer),
                                  value.little_endian);
        }

        return !plan->variants.empty();
    } catch (const std::exception& exception) {
        if (error != nullptr) {
            *error = exception.what();
        }
        return false;
    }
}

BytesDisplayEncoding ResolveBytesDisplayEncoding(const SearchValue& value) {
    if (value.type != SearchValueType::kBytes || value.bytes_value.empty()) {
        return BytesDisplayEncoding::kHex;
    }
    if (value.text_value.rfind("__jsx_text_utf16le__:", 0) == 0) {
        return BytesDisplayEncoding::kUtf16Le;
    }
    if (value.text_value.rfind("__jsx_text_utf8__:", 0) == 0) {
        return BytesDisplayEncoding::kUtf8;
    }
    return BytesDisplayEncoding::kHex;
}

std::string FormatDisplayValue(SearchValueType type,
                               const std::vector<uint8_t>& raw_bytes,
                               bool little_endian,
                               BytesDisplayEncoding bytes_display_encoding) {
    std::ostringstream stream;
    switch (type) {
        case SearchValueType::kI8:
            stream << static_cast<int>(DecodeBytes<int8_t>(raw_bytes, little_endian));
            return stream.str();
        case SearchValueType::kI16:
            stream << DecodeBytes<int16_t>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kI32:
            stream << DecodeBytes<int32_t>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kI64:
            stream << DecodeBytes<int64_t>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kF32:
            stream << DecodeBytes<float>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kF64:
            stream << DecodeBytes<double>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kBytes:
            switch (bytes_display_encoding) {
                case BytesDisplayEncoding::kUtf8:
                    return FormatUtf8Text(raw_bytes);
                case BytesDisplayEncoding::kUtf16Le:
                    return FormatUtf16LeText(raw_bytes);
                case BytesDisplayEncoding::kHex:
                    break;
            }
            return FormatHex(raw_bytes);
    }
    return {};
}

}  // namespace memory_tool
