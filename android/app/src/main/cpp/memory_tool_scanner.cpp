#include "memory_tool_scanner.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstring>
#include <functional>
#include <limits>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <unordered_set>

namespace memory_tool {

namespace {

constexpr size_t kChunkSize = 64 * 1024 * 1024;
constexpr size_t kNextScanBatchSize = 4 * 1024;
constexpr size_t kProgressEntryInterval = 16 * 1024;
constexpr size_t kInitialNextScanReportBatches = 4;
constexpr size_t kProgressRegionInterval = 32;
constexpr uint64_t kProgressByteInterval = 256ULL * 1024ULL * 1024ULL;
constexpr size_t kFuzzyInitialChunkSize = 8 * 1024 * 1024;
constexpr uint64_t kFuzzyCandidateWindowGap = 256;
constexpr size_t kFuzzyCandidateWindowMaxBytes = 256 * 1024;

struct IndexRange {
    size_t start = 0;
    size_t end = 0;
};

size_t ResolveStep(SearchValueType type) {
    switch (type) {
        case SearchValueType::kI8:
        case SearchValueType::kBytes:
            return 1;
        case SearchValueType::kI16:
            return 2;
        case SearchValueType::kI32:
        case SearchValueType::kF32:
            return 4;
        case SearchValueType::kI64:
        case SearchValueType::kF64:
            return 8;
    }
    return 1;
}

size_t ResolveNextScanWorkerCount(size_t entry_count) {
    if (entry_count <= kNextScanBatchSize) {
        return 1;
    }

    const unsigned int hardware_workers = std::thread::hardware_concurrency();
    const size_t preferred_workers = hardware_workers == 0 ? 4U : hardware_workers;
    const size_t target_entries_per_worker = kNextScanBatchSize * 4;
    const size_t required_workers =
        std::max<size_t>(1, (entry_count + target_entries_per_worker - 1) / target_entries_per_worker);
    return std::max<size_t>(1, std::min(preferred_workers, required_workers));
}

bool ShouldReportNextScanProgress(size_t processed_entry_count,
                                  size_t just_processed_count,
                                  size_t range_end_index,
                                  size_t current_end_index) {
    if (processed_entry_count == 0) {
        return false;
    }

    const bool is_range_completed = current_end_index == range_end_index;
    if (is_range_completed) {
        return true;
    }

    if (processed_entry_count <= (kNextScanBatchSize * kInitialNextScanReportBatches)) {
        return true;
    }

    return (processed_entry_count % kProgressEntryInterval) < just_processed_count;
}

std::vector<IndexRange> PartitionIndexRanges(size_t item_count, size_t worker_count) {
    if (item_count == 0 || worker_count == 0) {
        return {};
    }

    worker_count = std::min(item_count, worker_count);
    std::vector<IndexRange> ranges;
    ranges.reserve(worker_count);
    const size_t base_size = item_count / worker_count;
    const size_t remainder = item_count % worker_count;

    size_t start = 0;
    for (size_t index = 0; index < worker_count; ++index) {
        const size_t length = base_size + (index < remainder ? 1 : 0);
        ranges.push_back(IndexRange{start, start + length});
        start += length;
    }
    return ranges;
}

template <typename T>
T ReadScalar(const uint8_t* address) {
    T value{};
    std::memcpy(&value, address, sizeof(T));
    return value;
}

void AppendResult(uint64_t address,
                  uint64_t region_start,
                  SearchValueType matched_type,
                  std::vector<SearchResultEntry>* results) {
    if (results == nullptr) {
        return;
    }
    SearchResultEntry entry;
    entry.address = address;
    entry.region_start = region_start;
    entry.matched_type = matched_type;
    results->push_back(std::move(entry));
}

uint32_t ByteSwap32(uint32_t value) {
    return ((value & 0x000000FFU) << 24U) |
           ((value & 0x0000FF00U) << 8U) |
           ((value & 0x00FF0000U) >> 8U) |
           ((value & 0xFF000000U) >> 24U);
}

bool HostIsLittleEndian() {
    uint16_t value = 0x1;
    return *reinterpret_cast<uint8_t*>(&value) == 0x1;
}

uint32_t DecodeU32(const uint8_t* current, bool little_endian) {
    uint32_t value = ReadScalar<uint32_t>(current);
    if (HostIsLittleEndian() != little_endian) {
        value = ByteSwap32(value);
    }
    return value;
}

template <typename T>
T DecodeScalar(const uint8_t* current, bool little_endian) {
    std::array<uint8_t, sizeof(T)> bytes{};
    std::memcpy(bytes.data(), current, sizeof(T));
    if (HostIsLittleEndian() != little_endian) {
        std::reverse(bytes.begin(), bytes.end());
    }
    T value{};
    std::memcpy(&value, bytes.data(), sizeof(T));
    return value;
}

size_t ResolveFuzzyValueSize(SearchValueType type) {
    switch (type) {
        case SearchValueType::kI8:
            return sizeof(int8_t);
        case SearchValueType::kI16:
            return sizeof(int16_t);
        case SearchValueType::kI32:
            return sizeof(int32_t);
        case SearchValueType::kI64:
            return sizeof(int64_t);
        case SearchValueType::kF32:
            return sizeof(float);
        case SearchValueType::kF64:
            return sizeof(double);
        case SearchValueType::kBytes:
            break;
    }
    return 0;
}

size_t ResolveFuzzySlotCount(size_t byte_count, size_t value_size, size_t step) {
    if (value_size == 0 || step == 0 || byte_count < value_size) {
        return 0;
    }
    return 1 + ((byte_count - value_size) / step);
}

size_t ResolveFuzzySnapshotByteCount(size_t slot_count, size_t value_size, size_t step) {
    if (slot_count == 0 || value_size == 0 || step == 0) {
        return 0;
    }
    return value_size + ((slot_count - 1) * step);
}

uint64_t ReadRawBits(const uint8_t* current, size_t value_size);

size_t ResolveFuzzyInitialChunkSlotCount(size_t value_size, size_t step) {
    if (value_size == 0 || step == 0) {
        return 0;
    }
    if (kFuzzyInitialChunkSize <= value_size) {
        return 1;
    }
    return 1 + ((kFuzzyInitialChunkSize - value_size) / step);
}

size_t ResolveCandidateWindowEnd(const std::vector<FuzzyCandidate>& candidates,
                                 size_t start,
                                 size_t end,
                                 size_t value_size) {
    if (start >= end || value_size == 0) {
        return start;
    }

    size_t window_end = start + 1;
    const uint64_t region_start = candidates[start].region_start;
    const uint64_t window_start_address = candidates[start].address;
    uint64_t window_end_address = candidates[start].address + value_size;

    while (window_end < end) {
        const FuzzyCandidate& candidate = candidates[window_end];
        if (candidate.region_start != region_start) {
            break;
        }
        if (candidate.address < window_start_address) {
            break;
        }

        const uint64_t candidate_end_address = candidate.address + value_size;
        const uint64_t gap = candidate.address > window_end_address
                                 ? candidate.address - window_end_address
                                 : 0;
        const uint64_t next_window_size = candidate_end_address - window_start_address;
        if (gap > kFuzzyCandidateWindowGap ||
            next_window_size > kFuzzyCandidateWindowMaxBytes) {
            break;
        }

        window_end_address = std::max(window_end_address, candidate_end_address);
        ++window_end;
    }

    return window_end;
}

size_t ResolveResultWindowEnd(const std::vector<SearchResultEntry>& results,
                              size_t start,
                              size_t end,
                              size_t value_size) {
    if (start >= end || value_size == 0) {
        return start;
    }

    size_t window_end = start + 1;
    const uint64_t region_start = results[start].region_start;
    const uint64_t window_start_address = results[start].address;
    uint64_t window_end_address = results[start].address + value_size;

    while (window_end < end) {
        const SearchResultEntry& result = results[window_end];
        if (result.region_start != region_start) {
            break;
        }
        if (result.address < window_start_address) {
            break;
        }

        const uint64_t result_end_address = result.address + value_size;
        const uint64_t gap =
            result.address > window_end_address ? result.address - window_end_address : 0;
        const uint64_t next_window_size = result_end_address - window_start_address;
        if (gap > kFuzzyCandidateWindowGap ||
            next_window_size > kFuzzyCandidateWindowMaxBytes) {
            break;
        }

        window_end_address = std::max(window_end_address, result_end_address);
        ++window_end;
    }

    return window_end;
}

bool ReadValueBits(ProcessMemoryReader* reader,
                   uint64_t address,
                   size_t value_size,
                   uint64_t* value_bits) {
    if (reader == nullptr || value_bits == nullptr || value_size == 0 ||
        value_size > sizeof(uint64_t)) {
        return false;
    }

    std::array<uint8_t, sizeof(uint64_t)> buffer{};
    if (!reader->ReadInto(address, value_size, buffer.data())) {
        return false;
    }
    *value_bits = ReadRawBits(buffer.data(), value_size);
    return true;
}

uint64_t ReadRawBits(const uint8_t* current, size_t value_size) {
    uint64_t bits = 0;
    if (current == nullptr || value_size == 0 || value_size > sizeof(bits)) {
        return bits;
    }
    std::memcpy(&bits, current, value_size);
    return bits;
}

uint64_t ResolveRawBitMask(size_t value_size) {
    if (value_size == 0) {
        return 0;
    }
    if (value_size >= sizeof(uint64_t)) {
        return std::numeric_limits<uint64_t>::max();
    }
    return (uint64_t{1} << (value_size * 8U)) - 1U;
}

template <typename T>
T DecodeScalarBits(uint64_t bits, bool little_endian) {
    std::array<uint8_t, sizeof(T)> bytes{};
    std::memcpy(bytes.data(), &bits, sizeof(T));
    if (HostIsLittleEndian() != little_endian) {
        std::reverse(bytes.begin(), bytes.end());
    }
    T value{};
    std::memcpy(&value, bytes.data(), sizeof(T));
    return value;
}

bool MatchesOrderedFuzzyCompare(uint64_t previous_bits,
                                uint64_t current_bits,
                                SearchValueType type,
                                bool little_endian,
                                FuzzyCompareMode compare_mode) {
    switch (compare_mode) {
        case FuzzyCompareMode::kUnknown:
            return true;
        case FuzzyCompareMode::kUnchanged:
            return false;
        case FuzzyCompareMode::kChanged:
            return true;
        case FuzzyCompareMode::kIncreased:
        case FuzzyCompareMode::kDecreased:
            break;
    }

    switch (type) {
        case SearchValueType::kI8: {
            const int8_t previous_value = DecodeScalarBits<int8_t>(previous_bits, little_endian);
            const int8_t current_value = DecodeScalarBits<int8_t>(current_bits, little_endian);
            return compare_mode == FuzzyCompareMode::kIncreased
                       ? current_value > previous_value
                       : current_value < previous_value;
        }
        case SearchValueType::kI16: {
            const int16_t previous_value = DecodeScalarBits<int16_t>(previous_bits, little_endian);
            const int16_t current_value = DecodeScalarBits<int16_t>(current_bits, little_endian);
            return compare_mode == FuzzyCompareMode::kIncreased
                       ? current_value > previous_value
                       : current_value < previous_value;
        }
        case SearchValueType::kI32: {
            const int32_t previous_value = DecodeScalarBits<int32_t>(previous_bits, little_endian);
            const int32_t current_value = DecodeScalarBits<int32_t>(current_bits, little_endian);
            return compare_mode == FuzzyCompareMode::kIncreased
                       ? current_value > previous_value
                       : current_value < previous_value;
        }
        case SearchValueType::kI64: {
            const int64_t previous_value = DecodeScalarBits<int64_t>(previous_bits, little_endian);
            const int64_t current_value = DecodeScalarBits<int64_t>(current_bits, little_endian);
            return compare_mode == FuzzyCompareMode::kIncreased
                       ? current_value > previous_value
                       : current_value < previous_value;
        }
        case SearchValueType::kF32: {
            const float previous_value = DecodeScalarBits<float>(previous_bits, little_endian);
            const float current_value = DecodeScalarBits<float>(current_bits, little_endian);
            if (std::isnan(previous_value) || std::isnan(current_value)) {
                return false;
            }
            return compare_mode == FuzzyCompareMode::kIncreased
                       ? current_value > previous_value
                       : current_value < previous_value;
        }
        case SearchValueType::kF64: {
            const double previous_value = DecodeScalarBits<double>(previous_bits, little_endian);
            const double current_value = DecodeScalarBits<double>(current_bits, little_endian);
            if (std::isnan(previous_value) || std::isnan(current_value)) {
                return false;
            }
            return compare_mode == FuzzyCompareMode::kIncreased
                       ? current_value > previous_value
                       : current_value < previous_value;
        }
        case SearchValueType::kBytes:
            break;
    }
    return false;
}

bool MatchesFuzzyCompare(uint64_t previous_bits,
                         uint64_t current_bits,
                         SearchValueType type,
                         bool little_endian,
                         FuzzyCompareMode compare_mode,
                         size_t value_size) {
    const uint64_t comparison_mask = ResolveRawBitMask(value_size);
    const bool is_same = (previous_bits & comparison_mask) == (current_bits & comparison_mask);
    switch (compare_mode) {
        case FuzzyCompareMode::kUnknown:
            return true;
        case FuzzyCompareMode::kUnchanged:
            return is_same;
        case FuzzyCompareMode::kChanged:
            return !is_same;
        case FuzzyCompareMode::kIncreased:
        case FuzzyCompareMode::kDecreased:
            if (is_same) {
                return false;
            }
            return MatchesOrderedFuzzyCompare(previous_bits,
                                              current_bits,
                                              type,
                                              little_endian,
                                              compare_mode);
    }
    return false;
}

void SortResultsByAddress(std::vector<SearchResultEntry>* results) {
    if (results == nullptr) {
        return;
    }

    std::sort(results->begin(),
              results->end(),
              [](const SearchResultEntry& left, const SearchResultEntry& right) {
                  if (left.address != right.address) {
                      return left.address < right.address;
                  }
                  return static_cast<int>(left.matched_type) <
                         static_cast<int>(right.matched_type);
              });
}

void DeduplicateResultsByAddress(std::vector<SearchResultEntry>* results) {
    if (results == nullptr || results->empty()) {
        return;
    }

    std::unordered_set<uint64_t> seen_addresses;
    std::vector<SearchResultEntry> unique_results;
    unique_results.reserve(results->size());
    for (SearchResultEntry& entry : *results) {
        if (!seen_addresses.insert(entry.address).second) {
            continue;
        }
        unique_results.push_back(std::move(entry));
    }
    *results = std::move(unique_results);
}

bool IsPatternMatch(const uint8_t* current, const std::vector<uint8_t>& pattern) {
    if (current == nullptr || pattern.empty()) {
        return false;
    }

    switch (pattern.size()) {
        case 1:
            return current[0] == pattern[0];
        case 2:
            return ReadScalar<uint16_t>(current) == ReadScalar<uint16_t>(pattern.data());
        case 4:
            return ReadScalar<uint32_t>(current) == ReadScalar<uint32_t>(pattern.data());
        case 8:
            return ReadScalar<uint64_t>(current) == ReadScalar<uint64_t>(pattern.data());
        default:
            return std::memcmp(current, pattern.data(), pattern.size()) == 0;
    }
}

void ScanChunkForSingleByte(const uint8_t* buffer,
                            uint8_t needle,
                            uint64_t base_address,
                            uint64_t region_start,
                            size_t scan_limit,
                            SearchValueType matched_type,
                            std::vector<SearchResultEntry>* results) {
    const uint8_t* cursor = buffer;
    const uint8_t* end = buffer + static_cast<std::ptrdiff_t>(scan_limit);
    while (cursor < end) {
        const void* match = std::memchr(cursor, needle, static_cast<size_t>(end - cursor));
        if (match == nullptr) {
            break;
        }
        const auto* match_ptr = static_cast<const uint8_t*>(match);
        AppendResult(base_address + static_cast<uint64_t>(match_ptr - buffer),
                     region_start,
                     matched_type,
                     results);
        cursor = match_ptr + 1;
    }
}

template <typename T>
void ScanChunkForScalar(const uint8_t* buffer,
                        const std::vector<uint8_t>& pattern,
                        uint64_t base_address,
                        uint64_t region_start,
                        size_t scan_limit,
                        size_t step,
                        SearchValueType matched_type,
                        std::vector<SearchResultEntry>* results) {
    const T expected = ReadScalar<T>(pattern.data());
    for (size_t index = 0; index < scan_limit; index += step) {
        if (ReadScalar<T>(buffer + static_cast<std::ptrdiff_t>(index)) != expected) {
            continue;
        }
        AppendResult(base_address + index, region_start, matched_type, results);
    }
}

void ScanChunkForBytePattern(const uint8_t* buffer,
                             size_t buffer_size,
                             const std::vector<uint8_t>& pattern,
                             uint64_t base_address,
                             uint64_t region_start,
                             size_t scan_limit,
                             SearchValueType matched_type,
                             std::vector<SearchResultEntry>* results) {
    if (pattern.size() == 1) {
        ScanChunkForSingleByte(buffer,
                               pattern.front(),
                               base_address,
                               region_start,
                               scan_limit,
                               matched_type,
                               results);
        return;
    }

    const auto search_begin = buffer;
    auto search_cursor = search_begin;
    const auto search_end = buffer + static_cast<std::ptrdiff_t>(buffer_size);
    const auto searcher = std::boyer_moore_horspool_searcher(pattern.begin(), pattern.end());

    while (search_cursor < search_end) {
        const auto match = std::search(search_cursor, search_end, searcher);
        if (match == search_end) {
            break;
        }
        const size_t match_index =
            static_cast<size_t>(match - search_begin);
        if (match_index >= scan_limit) {
            break;
        }

        AppendResult(base_address + static_cast<uint64_t>(match_index),
                     region_start,
                     matched_type,
                     results);
        search_cursor = match + 1;
    }
}

void ScanChunkForGenericPattern(const uint8_t* buffer,
                                const std::vector<uint8_t>& pattern,
                                uint64_t base_address,
                                uint64_t region_start,
                                size_t scan_limit,
                                size_t step,
                                SearchValueType matched_type,
                                std::vector<SearchResultEntry>* results) {
    for (size_t index = 0; index < scan_limit; index += step) {
        if (std::memcmp(buffer + static_cast<std::ptrdiff_t>(index),
                        pattern.data(),
                        pattern.size()) != 0) {
            continue;
        }
        AppendResult(base_address + index, region_start, matched_type, results);
    }
}

void ScanChunkForPattern(const uint8_t* buffer,
                         size_t buffer_size,
                         const std::vector<uint8_t>& pattern,
                         SearchValueType type,
                         uint64_t base_address,
                         uint64_t region_start,
                         size_t scan_limit,
                         size_t step,
                         SearchValueType matched_type,
                         std::vector<SearchResultEntry>* results) {
    if (buffer == nullptr || results == nullptr || pattern.empty() || scan_limit == 0) {
        return;
    }

    if (step == 1) {
        ScanChunkForBytePattern(
            buffer,
            buffer_size,
            pattern,
            base_address,
            region_start,
            scan_limit,
            matched_type,
            results);
        return;
    }

    if (pattern.size() == step) {
        switch (type) {
            case SearchValueType::kI16:
                ScanChunkForScalar<uint16_t>(
                    buffer,
                    pattern,
                    base_address,
                    region_start,
                    scan_limit,
                    step,
                    matched_type,
                    results);
                return;
            case SearchValueType::kI32:
            case SearchValueType::kF32:
                ScanChunkForScalar<uint32_t>(
                    buffer,
                    pattern,
                    base_address,
                    region_start,
                    scan_limit,
                    step,
                    matched_type,
                    results);
                return;
            case SearchValueType::kI64:
            case SearchValueType::kF64:
                ScanChunkForScalar<uint64_t>(
                    buffer,
                    pattern,
                    base_address,
                    region_start,
                    scan_limit,
                    step,
                    matched_type,
                    results);
                return;
            case SearchValueType::kI8:
            case SearchValueType::kBytes:
                break;
        }
    }

    ScanChunkForGenericPattern(
        buffer,
        pattern,
        base_address,
        region_start,
        scan_limit,
        step,
        matched_type,
        results);
}


void ScanChunkForXorPattern(const uint8_t* buffer,
                            size_t buffer_size,
                            uint32_t target_value,
                            bool little_endian,
                            uint64_t base_address,
                            uint64_t region_start,
                            size_t scan_limit,
                            std::vector<SearchResultEntry>* results) {
    if (buffer == nullptr || results == nullptr || buffer_size < sizeof(uint32_t) || scan_limit == 0) {
        return;
    }

    const size_t max_limit = std::min(scan_limit, buffer_size - sizeof(uint32_t) + 1);
    for (size_t index = 0; index < max_limit; index += sizeof(uint32_t)) {
        const uint64_t address = base_address + index;
        const uint32_t stored_value = DecodeU32(buffer + static_cast<std::ptrdiff_t>(index),
                                                little_endian);
        const uint32_t address_low = static_cast<uint32_t>(address & 0xFFFFFFFFULL);
        if ((stored_value ^ address_low) != target_value) {
            continue;
        }
        AppendResult(address, region_start, SearchValueType::kI32, results);
    }
}

std::vector<SearchResultEntry> FinalizeMultiTypeFirstScan(std::vector<SearchResultEntry> results) {
    DeduplicateResultsByAddress(&results);
    SortResultsByAddress(&results);
    return results;
}

}  // namespace

std::vector<SearchResultEntry> FirstScan(ProcessMemoryReader* reader,
                                         const std::vector<MemoryRegion>& regions,
                                         const std::vector<uint8_t>& pattern,
                                         SearchValueType type,
                                         const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || pattern.empty()) {
        return results;
    }

    const size_t step = ResolveStep(type);
    const size_t overlap = pattern.size() > 1 ? pattern.size() - 1 : 0;
    SearchScanProgress progress;
    uint64_t last_reported_byte_count = 0;
    progress.total_region_count = regions.size();
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
    }
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    std::vector<uint8_t> buffer;
    buffer.reserve(kChunkSize + overlap);

    for (const MemoryRegion& region : regions) {
        for (uint64_t cursor = region.start_address; cursor < region.end_address;) {
            const size_t remaining = static_cast<size_t>(region.end_address - cursor);
            const size_t base_read_size = std::min(kChunkSize, remaining);
            const size_t read_size = std::min(remaining, base_read_size + overlap);

            buffer.resize(read_size);
            if (!reader->ReadInto(cursor, read_size, buffer.data()) ||
                buffer.size() < pattern.size()) {
                cursor += base_read_size;
                continue;
            }

            const size_t scan_limit = std::min(base_read_size, buffer.size() - pattern.size() + 1);
            ScanChunkForPattern(buffer.data(),
                                buffer.size(),
                                pattern,
                                type,
                                cursor,
                                region.start_address,
                                scan_limit,
                                step,
                                type,
                                &results);

            progress.processed_byte_count += base_read_size;
            progress.result_count = results.size();
            const bool should_report =
                (progress.processed_byte_count - last_reported_byte_count) >= kProgressByteInterval;
            if (should_report && progress_callback && !progress_callback(progress)) {
                return results;
            }
            if (should_report) {
                last_reported_byte_count = progress.processed_byte_count;
            }
            cursor += base_read_size;
        }

        ++progress.processed_region_count;
        progress.result_count = results.size();
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return results;
        }
    }

    return results;
}

std::vector<SearchResultEntry> FirstScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<MemoryRegion>& regions,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || variants.empty()) {
        return results;
    }

    size_t max_pattern_size = 0;
    for (const SearchPatternVariant& variant : variants) {
        if (variant.pattern.empty()) {
            continue;
        }
        max_pattern_size = std::max(max_pattern_size, variant.pattern.size());
    }
    if (max_pattern_size == 0) {
        return results;
    }

    const size_t overlap = max_pattern_size > 1 ? max_pattern_size - 1 : 0;
    SearchScanProgress progress;
    uint64_t last_reported_byte_count = 0;
    progress.total_region_count = regions.size();
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
    }
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    std::vector<uint8_t> buffer;
    buffer.reserve(kChunkSize + overlap);

    for (const MemoryRegion& region : regions) {
        for (uint64_t cursor = region.start_address; cursor < region.end_address;) {
            const size_t remaining = static_cast<size_t>(region.end_address - cursor);
            const size_t base_read_size = std::min(kChunkSize, remaining);
            const size_t read_size = std::min(remaining, base_read_size + overlap);

            buffer.resize(read_size);
            if (!reader->ReadInto(cursor, read_size, buffer.data()) || buffer.empty()) {
                cursor += base_read_size;
                continue;
            }

            for (const SearchPatternVariant& variant : variants) {
                if (variant.pattern.empty() || buffer.size() < variant.pattern.size()) {
                    continue;
                }

                const size_t scan_limit =
                    std::min(base_read_size, buffer.size() - variant.pattern.size() + 1);
                ScanChunkForPattern(buffer.data(),
                                    buffer.size(),
                                    variant.pattern,
                                    variant.type,
                                    cursor,
                                    region.start_address,
                                    scan_limit,
                                    ResolveStep(variant.type),
                                    variant.type,
                                    &results);
            }

            progress.processed_byte_count += base_read_size;
            progress.result_count = results.size();
            const bool should_report =
                (progress.processed_byte_count - last_reported_byte_count) >= kProgressByteInterval;
            if (should_report && progress_callback && !progress_callback(progress)) {
                return FinalizeMultiTypeFirstScan(std::move(results));
            }
            if (should_report) {
                last_reported_byte_count = progress.processed_byte_count;
            }
            cursor += base_read_size;
        }

        ++progress.processed_region_count;
        progress.result_count = results.size();
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return FinalizeMultiTypeFirstScan(std::move(results));
        }
    }

    return FinalizeMultiTypeFirstScan(std::move(results));
}

std::vector<SearchResultEntry> FirstScanXor(ProcessMemoryReader* reader,
                                            const std::vector<MemoryRegion>& regions,
                                            uint32_t target_value,
                                            bool little_endian,
                                            const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr) {
        return results;
    }

    constexpr size_t kPatternSize = sizeof(uint32_t);
    const size_t overlap = kPatternSize - 1;
    SearchScanProgress progress;
    uint64_t last_reported_byte_count = 0;
    progress.total_region_count = regions.size();
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
    }
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    std::vector<uint8_t> buffer;
    buffer.reserve(kChunkSize + overlap);

    for (const MemoryRegion& region : regions) {
        for (uint64_t cursor = region.start_address; cursor < region.end_address;) {
            const size_t remaining = static_cast<size_t>(region.end_address - cursor);
            const size_t base_read_size = std::min(kChunkSize, remaining);
            const size_t read_size = std::min(remaining, base_read_size + overlap);

            buffer.resize(read_size);
            if (!reader->ReadInto(cursor, read_size, buffer.data()) ||
                buffer.size() < kPatternSize) {
                cursor += base_read_size;
                continue;
            }

            const size_t scan_limit = std::min(base_read_size, buffer.size() - kPatternSize + 1);
            ScanChunkForXorPattern(buffer.data(),
                                   buffer.size(),
                                   target_value,
                                   little_endian,
                                   cursor,
                                   region.start_address,
                                   scan_limit,
                                   &results);

            progress.processed_byte_count += base_read_size;
            progress.result_count = results.size();
            const bool should_report =
                (progress.processed_byte_count - last_reported_byte_count) >= kProgressByteInterval;
            if (should_report && progress_callback && !progress_callback(progress)) {
                return results;
            }
            if (should_report) {
                last_reported_byte_count = progress.processed_byte_count;
            }
            cursor += base_read_size;
        }

        ++progress.processed_region_count;
        progress.result_count = results.size();
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return results;
        }
    }

    return results;
}

FuzzyScanState FirstScanFuzzy(ProcessMemoryReader* reader,
                              const std::vector<MemoryRegion>& regions,
                              SearchValueType type,
                              const SearchProgressCallback& progress_callback) {
    FuzzyScanState state;
    if (reader == nullptr) {
        return state;
    }

    const size_t value_size = ResolveFuzzyValueSize(type);
    const size_t step = ResolveStep(type);
    if (value_size == 0 || step == 0) {
        return state;
    }

    state.initial_regions = std::make_shared<std::vector<FuzzyInitialRegion>>();
    state.initial_regions->reserve(regions.size());

    SearchScanProgress progress;
    progress.total_region_count = regions.size();
    size_t total_slot_count = 0;
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
        total_slot_count +=
            ResolveFuzzySlotCount(static_cast<size_t>(region.size), value_size, step);
    }
    progress.total_entry_count = total_slot_count;
    if (progress_callback && !progress_callback(progress)) {
        return state;
    }

    for (const MemoryRegion& region : regions) {
        FuzzyInitialRegion initial_region;
        initial_region.region_start = region.start_address;
        initial_region.slot_count =
            ResolveFuzzySlotCount(static_cast<size_t>(region.size), value_size, step);
        const size_t snapshot_byte_count =
            ResolveFuzzySnapshotByteCount(initial_region.slot_count, value_size, step);
        if (snapshot_byte_count > 0) {
            initial_region.snapshot_bytes.resize(snapshot_byte_count);
            if (!reader->ReadInto(region.start_address,
                                  snapshot_byte_count,
                                  initial_region.snapshot_bytes.data())) {
                initial_region.snapshot_bytes.clear();
                initial_region.slot_count = 0;
            }
        }

        state.initial_regions->push_back(std::move(initial_region));
        ++progress.processed_region_count;
        progress.processed_byte_count += snapshot_byte_count;
        progress.processed_entry_count += state.initial_regions->back().slot_count;
        progress.result_count = progress.processed_entry_count;
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return state;
        }
    }

    return state;
}

FuzzyScanState SeedFuzzyFromResults(ProcessMemoryReader* reader,
                                    const std::vector<SearchResultEntry>& previous_results,
                                    const std::vector<uint8_t>& previous_value_bytes,
                                    SearchValueType type,
                                    bool little_endian,
                                    FuzzyCompareMode compare_mode,
                                    const SearchProgressCallback& progress_callback) {
    FuzzyScanState state;
    if (reader == nullptr || previous_results.empty() || previous_value_bytes.empty()) {
        return state;
    }

    const size_t value_size = ResolveFuzzyValueSize(type);
    if (value_size == 0 || previous_value_bytes.size() != value_size) {
        return state;
    }

    state.candidates = std::make_shared<std::vector<FuzzyCandidate>>();
    state.candidates->reserve(previous_results.size());
    const uint64_t previous_bits = ReadRawBits(previous_value_bytes.data(), value_size);

    SearchScanProgress progress;
    progress.total_region_count = previous_results.empty() ? 0 : 1;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(value_size);
    if (progress_callback && !progress_callback(progress)) {
        return state;
    }

    std::vector<uint8_t> window_buffer;
    size_t processed_entry_count = 0;
    uint64_t processed_byte_count = 0;

    for (size_t start = 0; start < previous_results.size();) {
        const size_t window_end =
            ResolveResultWindowEnd(previous_results, start, previous_results.size(), value_size);
        const size_t count = window_end - start;
        if (count == 0) {
            break;
        }

        const uint64_t window_start_address = previous_results[start].address;
        const uint64_t window_end_address = previous_results[window_end - 1].address + value_size;
        const size_t window_size =
            static_cast<size_t>(window_end_address - window_start_address);
        bool window_read_success = false;
        if (window_size > 0) {
            window_buffer.resize(window_size);
            window_read_success = reader->ReadInto(window_start_address,
                                                  window_size,
                                                  window_buffer.data());
        }

        for (size_t index = start; index < window_end; ++index) {
            const SearchResultEntry& candidate = previous_results[index];
            uint64_t current_bits = 0;
            if (window_read_success) {
                const size_t offset = static_cast<size_t>(candidate.address - window_start_address);
                current_bits = ReadRawBits(
                    window_buffer.data() + static_cast<std::ptrdiff_t>(offset),
                    value_size);
            } else if (!ReadValueBits(reader, candidate.address, value_size, &current_bits)) {
                continue;
            }

            const bool should_keep = MatchesFuzzyCompare(previous_bits,
                                                         current_bits,
                                                         type,
                                                         little_endian,
                                                         compare_mode,
                                                         value_size);
            if (!should_keep) {
                continue;
            }

            FuzzyCandidate next_candidate;
            next_candidate.address = candidate.address;
            next_candidate.region_start = candidate.region_start;
            next_candidate.previous_value_bits = current_bits;
            state.candidates->push_back(next_candidate);
        }

        processed_entry_count += count;
        processed_byte_count +=
            static_cast<uint64_t>(count) * static_cast<uint64_t>(value_size);
        progress.processed_entry_count = processed_entry_count;
        progress.processed_byte_count = processed_byte_count;
        progress.result_count = state.candidates->size();
        if (progress_callback &&
            ShouldReportNextScanProgress(processed_entry_count,
                                         count,
                                         previous_results.size(),
                                         window_end) &&
            !progress_callback(progress)) {
            return state;
        }

        start = window_end;
    }

    if (progress_callback) {
        progress.processed_region_count = progress.total_region_count;
        progress.result_count = state.candidates->size();
        progress_callback(progress);
    }

    return state;
}

size_t NextScanFuzzy(ProcessMemoryReader* reader,
                     SearchValueType type,
                     bool little_endian,
                     FuzzyCompareMode compare_mode,
                     const std::shared_ptr<std::vector<FuzzyCandidate>>& fuzzy_candidates,
                     std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                     const SearchProgressCallback& progress_callback) {
    if (reader == nullptr || next_fuzzy_candidates == nullptr || !fuzzy_candidates) {
        return 0;
    }

    const size_t value_size = ResolveFuzzyValueSize(type);
    if (value_size == 0) {
        return 0;
    }

    const std::vector<FuzzyCandidate>& candidates = *fuzzy_candidates;
    auto next_candidates = std::make_shared<std::vector<FuzzyCandidate>>();
    next_candidates->reserve(candidates.size());

    SearchScanProgress progress;
    progress.total_region_count = candidates.empty() ? 0 : 1;
    progress.total_entry_count = candidates.size();
    progress.total_byte_count =
        static_cast<uint64_t>(candidates.size()) * static_cast<uint64_t>(value_size);
    if (progress_callback && !progress_callback(progress)) {
        return 0;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(candidates.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(candidates.size(), worker_count);
    std::vector<std::vector<FuzzyCandidate>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        current_progress.processed_region_count =
            current_progress.total_region_count == 0 ||
                    current_progress.processed_entry_count == current_progress.total_entry_count
                ? current_progress.total_region_count
                : 0;
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &candidates,
                              &worker_results,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index,
                              type,
                              little_endian,
                              compare_mode,
                              value_size]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<uint8_t> window_buffer;
            SearchScanProgress local_progress;
            std::vector<FuzzyCandidate>& local_results = worker_results[worker_index];

            for (size_t start = range.start; start < range.end;) {
                if (should_stop.load()) {
                    return;
                }

                const size_t window_end =
                    ResolveCandidateWindowEnd(candidates, start, range.end, value_size);
                const size_t batch_processed_entries = window_end - start;
                if (batch_processed_entries == 0) {
                    break;
                }

                const uint64_t window_start_address = candidates[start].address;
                const uint64_t window_end_address =
                    candidates[window_end - 1].address + value_size;
                const size_t window_size =
                    static_cast<size_t>(window_end_address - window_start_address);
                bool window_read_success = false;
                if (window_size > 0) {
                    window_buffer.resize(window_size);
                    window_read_success =
                        local_reader.ReadInto(window_start_address, window_size, window_buffer.data());
                }

                if (window_read_success) {
                    for (size_t index = start; index < window_end; ++index) {
                        const FuzzyCandidate& candidate = candidates[index];
                        const size_t offset = static_cast<size_t>(candidate.address - window_start_address);
                        const uint64_t current_bits =
                            ReadRawBits(window_buffer.data() + static_cast<std::ptrdiff_t>(offset),
                                        value_size);
                        if (!MatchesFuzzyCompare(candidate.previous_value_bits,
                                                 current_bits,
                                                 type,
                                                 little_endian,
                                                 compare_mode,
                                                 value_size)) {
                            continue;
                        }

                        FuzzyCandidate next_candidate = candidate;
                        next_candidate.previous_value_bits = current_bits;
                        local_results.push_back(next_candidate);
                    }
                } else {
                    for (size_t index = start; index < window_end; ++index) {
                        const FuzzyCandidate& candidate = candidates[index];
                        uint64_t current_bits = 0;
                        if (!ReadValueBits(&local_reader,
                                           candidate.address,
                                           value_size,
                                           &current_bits)) {
                            continue;
                        }
                        if (!MatchesFuzzyCompare(candidate.previous_value_bits,
                                                 current_bits,
                                                 type,
                                                 little_endian,
                                                 compare_mode,
                                                 value_size)) {
                            continue;
                        }

                        FuzzyCandidate next_candidate = candidate;
                        next_candidate.previous_value_bits = current_bits;
                        local_results.push_back(next_candidate);
                    }
                }

                const uint64_t batch_processed_bytes =
                    static_cast<uint64_t>(batch_processed_entries) * static_cast<uint64_t>(value_size);
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report = ShouldReportNextScanProgress(
                    local_progress.processed_entry_count,
                    batch_processed_entries,
                    range.end,
                    window_end);
                if (should_report && !report_progress()) {
                    return;
                }

                start = window_end;
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return 0;
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    next_candidates->reserve(result_count);
    for (auto& entries : worker_results) {
        next_candidates->insert(next_candidates->end(),
                                std::make_move_iterator(entries.begin()),
                                std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_region_count = progress.total_region_count;
        completed_progress.processed_entry_count = candidates.size();
        completed_progress.processed_byte_count = progress.total_byte_count;
        completed_progress.result_count = next_candidates->size();
        progress_callback(completed_progress);
    }

    *next_fuzzy_candidates = std::move(next_candidates);
    return result_count;
}

size_t NextScanFuzzyExact(ProcessMemoryReader* reader,
                          const std::vector<uint8_t>& pattern,
                          SearchValueType type,
                          const std::shared_ptr<std::vector<FuzzyCandidate>>& fuzzy_candidates,
                          std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                          const SearchProgressCallback& progress_callback) {
    if (reader == nullptr || next_fuzzy_candidates == nullptr || !fuzzy_candidates ||
        pattern.empty()) {
        return 0;
    }

    const size_t value_size = ResolveFuzzyValueSize(type);
    if (value_size == 0 || pattern.size() != value_size) {
        return 0;
    }

    const std::vector<FuzzyCandidate>& candidates = *fuzzy_candidates;
    auto next_candidates = std::make_shared<std::vector<FuzzyCandidate>>();
    next_candidates->reserve(candidates.size());
    const uint64_t target_bits = ReadRawBits(pattern.data(), pattern.size());
    const uint64_t comparison_mask = ResolveRawBitMask(pattern.size());

    SearchScanProgress progress;
    progress.total_region_count = candidates.empty() ? 0 : 1;
    progress.total_entry_count = candidates.size();
    progress.total_byte_count =
        static_cast<uint64_t>(candidates.size()) * static_cast<uint64_t>(pattern.size());
    if (progress_callback && !progress_callback(progress)) {
        return 0;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(candidates.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(candidates.size(), worker_count);
    std::vector<std::vector<FuzzyCandidate>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        current_progress.processed_region_count =
            current_progress.total_region_count == 0 ||
                    current_progress.processed_entry_count == current_progress.total_entry_count
                ? current_progress.total_region_count
                : 0;
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &candidates,
                              &worker_results,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index,
                              value_size,
                              target_bits,
                              comparison_mask]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<uint8_t> window_buffer;
            SearchScanProgress local_progress;
            std::vector<FuzzyCandidate>& local_results = worker_results[worker_index];

            for (size_t start = range.start; start < range.end;) {
                if (should_stop.load()) {
                    return;
                }

                const size_t window_end =
                    ResolveCandidateWindowEnd(candidates, start, range.end, value_size);
                const size_t batch_processed_entries = window_end - start;
                if (batch_processed_entries == 0) {
                    break;
                }

                const uint64_t window_start_address = candidates[start].address;
                const uint64_t window_end_address =
                    candidates[window_end - 1].address + value_size;
                const size_t window_size =
                    static_cast<size_t>(window_end_address - window_start_address);
                bool window_read_success = false;
                if (window_size > 0) {
                    window_buffer.resize(window_size);
                    window_read_success =
                        local_reader.ReadInto(window_start_address, window_size, window_buffer.data());
                }

                if (window_read_success) {
                    for (size_t index = start; index < window_end; ++index) {
                        const FuzzyCandidate& candidate = candidates[index];
                        const size_t offset = static_cast<size_t>(candidate.address - window_start_address);
                        const uint64_t current_bits =
                            ReadRawBits(window_buffer.data() + static_cast<std::ptrdiff_t>(offset),
                                        value_size);
                        if ((current_bits & comparison_mask) != (target_bits & comparison_mask)) {
                            continue;
                        }

                        FuzzyCandidate next_candidate = candidate;
                        next_candidate.previous_value_bits = current_bits;
                        local_results.push_back(next_candidate);
                    }
                } else {
                    for (size_t index = start; index < window_end; ++index) {
                        const FuzzyCandidate& candidate = candidates[index];
                        uint64_t current_bits = 0;
                        if (!ReadValueBits(&local_reader,
                                           candidate.address,
                                           value_size,
                                           &current_bits)) {
                            continue;
                        }
                        if ((current_bits & comparison_mask) != (target_bits & comparison_mask)) {
                            continue;
                        }

                        FuzzyCandidate next_candidate = candidate;
                        next_candidate.previous_value_bits = current_bits;
                        local_results.push_back(next_candidate);
                    }
                }

                const uint64_t batch_processed_bytes =
                    static_cast<uint64_t>(batch_processed_entries) * static_cast<uint64_t>(value_size);
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report = ShouldReportNextScanProgress(
                    local_progress.processed_entry_count,
                    batch_processed_entries,
                    range.end,
                    window_end);
                if (should_report && !report_progress()) {
                    return;
                }

                start = window_end;
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return 0;
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    next_candidates->reserve(result_count);
    for (auto& entries : worker_results) {
        next_candidates->insert(next_candidates->end(),
                                std::make_move_iterator(entries.begin()),
                                std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_region_count = progress.total_region_count;
        completed_progress.processed_entry_count = candidates.size();
        completed_progress.processed_byte_count = progress.total_byte_count;
        completed_progress.result_count = next_candidates->size();
        progress_callback(completed_progress);
    }

    *next_fuzzy_candidates = std::move(next_candidates);
    return result_count;
}

size_t NextScanFuzzyFromInitial(ProcessMemoryReader* reader,
                                const std::shared_ptr<std::vector<FuzzyInitialRegion>>&
                                    fuzzy_initial_regions,
                                SearchValueType type,
                                bool little_endian,
                                FuzzyCompareMode compare_mode,
                                std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                                const SearchProgressCallback& progress_callback) {
    if (reader == nullptr || next_fuzzy_candidates == nullptr || !fuzzy_initial_regions) {
        return 0;
    }

    const size_t value_size = ResolveFuzzyValueSize(type);
    const size_t step = ResolveStep(type);
    if (value_size == 0 || step == 0) {
        return 0;
    }

    SearchScanProgress progress;
    progress.total_region_count = fuzzy_initial_regions->size();
    size_t total_slot_count = 0;
    for (const FuzzyInitialRegion& region : *fuzzy_initial_regions) {
        total_slot_count += region.slot_count;
        progress.total_byte_count += region.snapshot_bytes.size();
    }
    progress.total_entry_count = total_slot_count;
    if (progress_callback && !progress_callback(progress)) {
        return 0;
    }

    auto next_candidates = std::make_shared<std::vector<FuzzyCandidate>>();
    next_candidates->reserve(total_slot_count);
    const size_t chunk_slot_count = ResolveFuzzyInitialChunkSlotCount(value_size, step);

    for (const FuzzyInitialRegion& region : *fuzzy_initial_regions) {
        if (region.slot_count == 0 || region.snapshot_bytes.empty()) {
            ++progress.processed_region_count;
            if (progress_callback && !progress_callback(progress)) {
                return 0;
            }
            continue;
        }

        std::vector<uint8_t> chunk_buffer;
        for (size_t start = 0; start < region.slot_count; start += chunk_slot_count) {
            const size_t count = std::min(chunk_slot_count, region.slot_count - start);
            const size_t read_size = ResolveFuzzySnapshotByteCount(count, value_size, step);
            const uint64_t read_address = region.region_start + (start * step);
            bool chunk_read_success = false;
            if (read_size > 0) {
                chunk_buffer.resize(read_size);
                chunk_read_success = reader->ReadInto(read_address, read_size, chunk_buffer.data());
            }

            if (chunk_read_success) {
                for (size_t index = 0; index < count; ++index) {
                    const size_t slot_index = start + index;
                    const size_t offset = slot_index * step;
                    const size_t local_offset = index * step;
                    const uint64_t previous_bits = ReadRawBits(
                        region.snapshot_bytes.data() + static_cast<std::ptrdiff_t>(offset),
                        value_size);
                    const uint64_t current_bits = ReadRawBits(
                        chunk_buffer.data() + static_cast<std::ptrdiff_t>(local_offset),
                        value_size);
                    if (!MatchesFuzzyCompare(previous_bits,
                                             current_bits,
                                             type,
                                             little_endian,
                                             compare_mode,
                                             value_size)) {
                        continue;
                    }

                    FuzzyCandidate candidate;
                    candidate.address = region.region_start + (slot_index * step);
                    candidate.region_start = region.region_start;
                    candidate.previous_value_bits = current_bits;
                    next_candidates->push_back(candidate);
                }
            } else {
                for (size_t index = 0; index < count; ++index) {
                    const size_t slot_index = start + index;
                    const size_t offset = slot_index * step;
                    const uint64_t address = region.region_start + (slot_index * step);
                    const uint64_t previous_bits = ReadRawBits(
                        region.snapshot_bytes.data() + static_cast<std::ptrdiff_t>(offset),
                        value_size);
                    uint64_t current_bits = 0;
                    if (!ReadValueBits(reader, address, value_size, &current_bits)) {
                        continue;
                    }
                    if (!MatchesFuzzyCompare(previous_bits,
                                             current_bits,
                                             type,
                                             little_endian,
                                             compare_mode,
                                             value_size)) {
                        continue;
                    }

                    FuzzyCandidate candidate;
                    candidate.address = address;
                    candidate.region_start = region.region_start;
                    candidate.previous_value_bits = current_bits;
                    next_candidates->push_back(candidate);
                }
            }

            progress.processed_entry_count += count;
            progress.processed_byte_count +=
                static_cast<uint64_t>(count) * static_cast<uint64_t>(value_size);
            progress.result_count = next_candidates->size();
            if (progress_callback &&
                ShouldReportNextScanProgress(progress.processed_entry_count,
                                             count,
                                             progress.total_entry_count,
                                             progress.processed_entry_count) &&
                !progress_callback(progress)) {
                return 0;
            }
        }

        ++progress.processed_region_count;
        progress.result_count = next_candidates->size();
        if (progress_callback && !progress_callback(progress)) {
            return 0;
        }
    }

    *next_fuzzy_candidates = std::move(next_candidates);
    return (*next_fuzzy_candidates)->size();
}

size_t NextScanFuzzyExactFromInitial(ProcessMemoryReader* reader,
                                     const std::shared_ptr<std::vector<FuzzyInitialRegion>>&
                                         fuzzy_initial_regions,
                                     const std::vector<uint8_t>& pattern,
                                     SearchValueType type,
                                     std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                                     const SearchProgressCallback& progress_callback) {
    if (reader == nullptr || next_fuzzy_candidates == nullptr || !fuzzy_initial_regions ||
        pattern.empty()) {
        return 0;
    }

    const size_t value_size = ResolveFuzzyValueSize(type);
    const size_t step = ResolveStep(type);
    if (value_size == 0 || step == 0 || pattern.size() != value_size) {
        return 0;
    }

    const uint64_t target_bits = ReadRawBits(pattern.data(), pattern.size());
    const uint64_t comparison_mask = ResolveRawBitMask(pattern.size());

    SearchScanProgress progress;
    progress.total_region_count = fuzzy_initial_regions->size();
    size_t total_slot_count = 0;
    for (const FuzzyInitialRegion& region : *fuzzy_initial_regions) {
        total_slot_count += region.slot_count;
        progress.total_byte_count += region.snapshot_bytes.size();
    }
    progress.total_entry_count = total_slot_count;
    if (progress_callback && !progress_callback(progress)) {
        return 0;
    }

    auto next_candidates = std::make_shared<std::vector<FuzzyCandidate>>();
    next_candidates->reserve(total_slot_count);
    const size_t chunk_slot_count = ResolveFuzzyInitialChunkSlotCount(value_size, step);

    for (const FuzzyInitialRegion& region : *fuzzy_initial_regions) {
        if (region.slot_count == 0 || region.snapshot_bytes.empty()) {
            ++progress.processed_region_count;
            if (progress_callback && !progress_callback(progress)) {
                return 0;
            }
            continue;
        }

        std::vector<uint8_t> chunk_buffer;
        for (size_t start = 0; start < region.slot_count; start += chunk_slot_count) {
            const size_t count = std::min(chunk_slot_count, region.slot_count - start);
            const size_t read_size = ResolveFuzzySnapshotByteCount(count, value_size, step);
            const uint64_t read_address = region.region_start + (start * step);
            bool chunk_read_success = false;
            if (read_size > 0) {
                chunk_buffer.resize(read_size);
                chunk_read_success = reader->ReadInto(read_address, read_size, chunk_buffer.data());
            }

            if (chunk_read_success) {
                for (size_t index = 0; index < count; ++index) {
                    const size_t slot_index = start + index;
                    const size_t local_offset = index * step;
                    const uint64_t current_bits = ReadRawBits(
                        chunk_buffer.data() + static_cast<std::ptrdiff_t>(local_offset),
                        value_size);
                    if ((current_bits & comparison_mask) != (target_bits & comparison_mask)) {
                        continue;
                    }

                    FuzzyCandidate candidate;
                    candidate.address = region.region_start + (slot_index * step);
                    candidate.region_start = region.region_start;
                    candidate.previous_value_bits = current_bits;
                    next_candidates->push_back(candidate);
                }
            } else {
                for (size_t index = 0; index < count; ++index) {
                    const size_t slot_index = start + index;
                    const uint64_t address = region.region_start + (slot_index * step);
                    uint64_t current_bits = 0;
                    if (!ReadValueBits(reader, address, value_size, &current_bits)) {
                        continue;
                    }
                    if ((current_bits & comparison_mask) != (target_bits & comparison_mask)) {
                        continue;
                    }

                    FuzzyCandidate candidate;
                    candidate.address = address;
                    candidate.region_start = region.region_start;
                    candidate.previous_value_bits = current_bits;
                    next_candidates->push_back(candidate);
                }
            }

            progress.processed_entry_count += count;
            progress.processed_byte_count +=
                static_cast<uint64_t>(count) * static_cast<uint64_t>(value_size);
            progress.result_count = next_candidates->size();
            if (progress_callback &&
                ShouldReportNextScanProgress(progress.processed_entry_count,
                                             count,
                                             progress.total_entry_count,
                                             progress.processed_entry_count) &&
                !progress_callback(progress)) {
                return 0;
            }
        }

        ++progress.processed_region_count;
        progress.result_count = next_candidates->size();
        if (progress_callback && !progress_callback(progress)) {
            return 0;
        }
    }

    *next_fuzzy_candidates = std::move(next_candidates);
    return (*next_fuzzy_candidates)->size();
}

std::vector<SearchResultEntry> NextScan(ProcessMemoryReader* reader,
                                        const std::vector<SearchResultEntry>& previous_results,
                                        const std::vector<uint8_t>& pattern,
                                        const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || pattern.empty()) {
        return results;
    }

    SearchScanProgress progress;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(pattern.size());
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(previous_results.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(previous_results.size(), worker_count);
    std::vector<std::vector<SearchResultEntry>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &previous_results,
                              &worker_results,
                              &pattern,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<uint64_t> addresses;
            addresses.reserve(kNextScanBatchSize);
            FlatReadBatch batch;
            SearchScanProgress local_progress;
            std::vector<SearchResultEntry>& local_results = worker_results[worker_index];

            for (size_t start = range.start; start < range.end; start += kNextScanBatchSize) {
                if (should_stop.load()) {
                    return;
                }

                const size_t count = std::min(kNextScanBatchSize, range.end - start);
                addresses.clear();
                for (size_t index = 0; index < count; ++index) {
                    addresses.push_back(previous_results[start + index].address);
                }

                local_reader.ReadManyFlat(addresses, pattern.size(), &batch);
                for (size_t index = 0; index < count; ++index) {
                    if (!batch.HasValue(index)) {
                        continue;
                    }

                    const SearchResultEntry& candidate = previous_results[start + index];
                    if (!IsPatternMatch(batch.ValueAt(index), pattern)) {
                        continue;
                    }
                    local_results.push_back(candidate);
                }

                const size_t batch_processed_entries = count;
                const uint64_t batch_processed_bytes =
                    static_cast<uint64_t>(count) * static_cast<uint64_t>(pattern.size());
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report = ShouldReportNextScanProgress(
                    local_progress.processed_entry_count,
                    batch_processed_entries,
                    range.end,
                    start + count);
                if (should_report) {
                    if (!report_progress()) {
                        return;
                    }
                }
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return {};
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    results.reserve(result_count);
    for (auto& entries : worker_results) {
        results.insert(results.end(),
                       std::make_move_iterator(entries.begin()),
                       std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_entry_count = previous_results.size();
        completed_progress.processed_byte_count = progress.total_byte_count;
        completed_progress.result_count = results.size();
        progress_callback(completed_progress);
    }
    return results;
}

std::vector<SearchResultEntry> NextScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<SearchResultEntry>& previous_results,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || variants.empty()) {
        return results;
    }

    std::unordered_map<int, std::vector<uint8_t>> pattern_by_type;
    size_t max_pattern_size = 0;
    for (const SearchPatternVariant& variant : variants) {
        if (variant.pattern.empty()) {
            continue;
        }
        pattern_by_type[static_cast<int>(variant.type)] = variant.pattern;
        max_pattern_size = std::max(max_pattern_size, variant.pattern.size());
    }
    if (pattern_by_type.empty() || max_pattern_size == 0) {
        return results;
    }

    SearchScanProgress progress;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(max_pattern_size);
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(previous_results.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(previous_results.size(), worker_count);
    std::vector<std::vector<SearchResultEntry>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &previous_results,
                              &worker_results,
                              &pattern_by_type,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index,
                              max_pattern_size]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<SearchResultEntry>& local_results = worker_results[worker_index];
            SearchScanProgress local_progress;

            for (size_t start = range.start; start < range.end; start += kNextScanBatchSize) {
                if (should_stop.load()) {
                    return;
                }

                const size_t count = std::min(kNextScanBatchSize, range.end - start);
                uint64_t batch_processed_bytes = 0;
                for (size_t index = 0; index < count; ++index) {
                    const SearchResultEntry& candidate = previous_results[start + index];
                    const auto pattern_iterator =
                        pattern_by_type.find(static_cast<int>(candidate.matched_type));
                    if (pattern_iterator == pattern_by_type.end()) {
                        continue;
                    }

                    const std::vector<uint8_t>& pattern = pattern_iterator->second;
                    batch_processed_bytes += static_cast<uint64_t>(pattern.size());
                    std::vector<uint8_t> buffer;
                    if (!local_reader.Read(candidate.address, pattern.size(), &buffer)) {
                        continue;
                    }
                    if (!IsPatternMatch(buffer.data(), pattern)) {
                        continue;
                    }
                    local_results.push_back(candidate);
                }

                const size_t batch_processed_entries = count;
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report = ShouldReportNextScanProgress(
                    local_progress.processed_entry_count,
                    batch_processed_entries,
                    range.end,
                    start + count);
                if (should_report && !report_progress()) {
                    return;
                }
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return {};
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    results.reserve(result_count);
    for (auto& entries : worker_results) {
        results.insert(results.end(),
                       std::make_move_iterator(entries.begin()),
                       std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_entry_count = previous_results.size();
        completed_progress.processed_byte_count = processed_byte_count.load();
        completed_progress.result_count = results.size();
        progress_callback(completed_progress);
    }
    return results;
}

std::vector<SearchResultEntry> NextScanXor(ProcessMemoryReader* reader,
                                           const std::vector<SearchResultEntry>& previous_results,
                                           uint32_t target_value,
                                           bool little_endian,
                                           const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr) {
        return results;
    }

    constexpr size_t kPatternSize = sizeof(uint32_t);
    SearchScanProgress progress;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(kPatternSize);
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(previous_results.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(previous_results.size(), worker_count);
    std::vector<std::vector<SearchResultEntry>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &previous_results,
                              &worker_results,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index,
                              target_value,
                              little_endian]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<SearchResultEntry>& local_results = worker_results[worker_index];
            SearchScanProgress local_progress;

            for (size_t start = range.start; start < range.end; start += kNextScanBatchSize) {
                if (should_stop.load()) {
                    return;
                }

                const size_t count = std::min(kNextScanBatchSize, range.end - start);
                for (size_t index = 0; index < count; ++index) {
                    const SearchResultEntry& candidate = previous_results[start + index];
                    std::vector<uint8_t> buffer;
                    if (!local_reader.Read(candidate.address, kPatternSize, &buffer) ||
                        buffer.size() < kPatternSize) {
                        continue;
                    }

                    const uint32_t stored_value = DecodeU32(buffer.data(), little_endian);
                    const uint32_t address_low =
                        static_cast<uint32_t>(candidate.address & 0xFFFFFFFFULL);
                    if ((stored_value ^ address_low) != target_value) {
                        continue;
                    }
                    local_results.push_back(candidate);
                }

                const size_t batch_processed_entries = count;
                const uint64_t batch_processed_bytes =
                    static_cast<uint64_t>(count) * static_cast<uint64_t>(kPatternSize);
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report = ShouldReportNextScanProgress(
                    local_progress.processed_entry_count,
                    batch_processed_entries,
                    range.end,
                    start + count);
                if (should_report && !report_progress()) {
                    return;
                }
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return {};
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    results.reserve(result_count);
    for (auto& entries : worker_results) {
        results.insert(results.end(),
                       std::make_move_iterator(entries.begin()),
                       std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_entry_count = previous_results.size();
        completed_progress.processed_byte_count = progress.total_byte_count;
        completed_progress.result_count = results.size();
        progress_callback(completed_progress);
    }
    return results;
}

}  // namespace memory_tool
