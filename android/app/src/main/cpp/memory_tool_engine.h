#ifndef JSXPOSEDX_MEMORY_TOOL_ENGINE_H
#define JSXPOSEDX_MEMORY_TOOL_ENGINE_H

#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <vector>

#include "memory_tool_scanner.h"
#include "memory_tool_session.h"

namespace memory_tool {

class MemoryToolEngine {
public:
    static MemoryToolEngine& Instance();

    std::vector<MemoryRegion> GetMemoryRegions(int pid,
                                               int offset,
                                               int limit,
                                               bool readable_only,
                                               bool include_anonymous,
                                               bool include_file_backed);

    SearchSessionStateView GetSearchSessionState();

    SearchTaskStateView GetSearchTaskState();

    std::vector<SearchResultView> GetSearchResults(int offset, int limit);

    std::vector<MemoryValuePreview> ReadMemoryValues(const std::vector<MemoryReadRequest>& requests);

    void FirstScan(int pid,
                   const SearchValue& value,
                   SearchMatchMode match_mode,
                   bool scan_all_readable_regions);

    void NextScan(const SearchValue& value, SearchMatchMode match_mode);

    void CancelSearch();

    void ResetSearchSession();

private:
    MemoryToolEngine() = default;

    struct SearchTaskRuntime {
        uint64_t generation = 0;
        std::chrono::steady_clock::time_point started_at{};
        std::shared_ptr<std::atomic_bool> cancel_flag;
        SearchTaskStateView view;
    };

    SearchSessionStateView BuildSessionStateLocked() const;

    SearchTaskStateView BuildTaskStateLocked() const;

    SearchResultView BuildSearchResultViewLocked(const SearchResultEntry& entry) const;

    void EnsureActiveSessionLocked() const;

    void EnsureTaskNotRunningLocked() const;

    uint64_t StartTaskLocked(bool is_first_scan, int pid);

    bool UpdateTaskProgress(uint64_t generation, const SearchScanProgress& progress);

    void FinishTaskSuccess(uint64_t generation, SearchSession&& next_session, size_t result_count);

    void FinishTaskFailure(uint64_t generation, const std::string& message);

    SearchSession session_;
    SearchTaskRuntime task_;
    uint64_t task_generation_counter_ = 0;
    mutable std::mutex mutex_;
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_ENGINE_H
