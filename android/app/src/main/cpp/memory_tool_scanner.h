#ifndef JSXPOSEDX_MEMORY_TOOL_SCANNER_H
#define JSXPOSEDX_MEMORY_TOOL_SCANNER_H

#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

#include "memory_tool_reader.h"
#include "memory_tool_session.h"

namespace memory_tool {

struct SearchScanProgress {
    size_t processed_region_count = 0;
    size_t total_region_count = 0;
    size_t processed_entry_count = 0;
    size_t total_entry_count = 0;
    uint64_t processed_byte_count = 0;
    uint64_t total_byte_count = 0;
    size_t result_count = 0;
};

using SearchProgressCallback = std::function<bool(const SearchScanProgress&)>;

struct SearchPatternVariant {
    SearchValueType type = SearchValueType::kI32;
    std::vector<uint8_t> pattern;
};

struct FuzzyScanState {
    std::shared_ptr<std::vector<FuzzyInitialRegion>> initial_regions;
    std::shared_ptr<std::vector<FuzzyCandidate>> candidates;
};

std::vector<SearchResultEntry> FirstScan(ProcessMemoryReader* reader,
                                         const std::vector<MemoryRegion>& regions,
                                         const std::vector<uint8_t>& pattern,
                                         SearchValueType type,
                                         const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> FirstScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<MemoryRegion>& regions,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> FirstScanXor(ProcessMemoryReader* reader,
                                            const std::vector<MemoryRegion>& regions,
                                            uint32_t target_value,
                                            bool little_endian,
                                            const SearchProgressCallback& progress_callback);

FuzzyScanState FirstScanFuzzy(ProcessMemoryReader* reader,
                              const std::vector<MemoryRegion>& regions,
                              SearchValueType type,
                              const SearchProgressCallback& progress_callback);

FuzzyScanState SeedFuzzyFromResults(ProcessMemoryReader* reader,
                                    const std::vector<SearchResultEntry>& previous_results,
                                    const std::vector<uint8_t>& previous_value_bytes,
                                    SearchValueType type,
                                    bool little_endian,
                                    FuzzyCompareMode compare_mode,
                                    const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> NextScan(ProcessMemoryReader* reader,
                                        const std::vector<SearchResultEntry>& previous_results,
                                        const std::vector<uint8_t>& pattern,
                                        const SearchProgressCallback& progress_callback);

size_t NextScanFuzzy(ProcessMemoryReader* reader,
                     SearchValueType type,
                     bool little_endian,
                     FuzzyCompareMode compare_mode,
                     const std::shared_ptr<std::vector<FuzzyCandidate>>& fuzzy_candidates,
                     std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                     const SearchProgressCallback& progress_callback);

size_t NextScanFuzzyExact(ProcessMemoryReader* reader,
                          const std::vector<uint8_t>& pattern,
                          SearchValueType type,
                          const std::shared_ptr<std::vector<FuzzyCandidate>>& fuzzy_candidates,
                          std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                          const SearchProgressCallback& progress_callback);

size_t NextScanFuzzyFromInitial(ProcessMemoryReader* reader,
                                const std::shared_ptr<std::vector<FuzzyInitialRegion>>&
                                    fuzzy_initial_regions,
                                SearchValueType type,
                                bool little_endian,
                                FuzzyCompareMode compare_mode,
                                std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                                const SearchProgressCallback& progress_callback);

size_t NextScanFuzzyExactFromInitial(ProcessMemoryReader* reader,
                                     const std::shared_ptr<std::vector<FuzzyInitialRegion>>&
                                         fuzzy_initial_regions,
                                     const std::vector<uint8_t>& pattern,
                                     SearchValueType type,
                                     std::shared_ptr<std::vector<FuzzyCandidate>>* next_fuzzy_candidates,
                                     const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> NextScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<SearchResultEntry>& previous_results,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> NextScanXor(ProcessMemoryReader* reader,
                                           const std::vector<SearchResultEntry>& previous_results,
                                           uint32_t target_value,
                                           bool little_endian,
                                           const SearchProgressCallback& progress_callback);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_SCANNER_H
