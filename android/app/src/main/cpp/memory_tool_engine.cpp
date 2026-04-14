#include "memory_tool_engine.h"

#include <algorithm>
#include <stdexcept>
#include <thread>
#include <utility>

#include "memory_tool_reader.h"
#include "memory_tool_regions.h"
#include "memory_tool_value.h"

namespace memory_tool {

namespace {

uint64_t ElapsedMilliseconds(const std::chrono::steady_clock::time_point& started_at) {
    if (started_at == std::chrono::steady_clock::time_point{}) {
        return 0;
    }
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
                                     std::chrono::steady_clock::now() - started_at)
                                     .count());
}

}  // namespace

MemoryToolEngine& MemoryToolEngine::Instance() {
    static MemoryToolEngine instance;
    return instance;
}

std::vector<MemoryRegion> MemoryToolEngine::GetMemoryRegions(int pid,
                                                             int offset,
                                                             int limit,
                                                             bool readable_only,
                                                             bool include_anonymous,
                                                             bool include_file_backed) {
    const std::vector<MemoryRegion> all_regions =
        ReadProcessRegions(pid, readable_only, include_anonymous, include_file_backed);
    if (limit <= 0 || offset >= static_cast<int>(all_regions.size())) {
        return {};
    }

    const size_t start = static_cast<size_t>(std::max(offset, 0));
    const size_t end = std::min(all_regions.size(), start + static_cast<size_t>(limit));
    return std::vector<MemoryRegion>(all_regions.begin() + static_cast<std::ptrdiff_t>(start),
                                     all_regions.begin() + static_cast<std::ptrdiff_t>(end));
}

SearchSessionStateView MemoryToolEngine::GetSearchSessionState() {
    std::lock_guard<std::mutex> lock(mutex_);
    return BuildSessionStateLocked();
}

SearchTaskStateView MemoryToolEngine::GetSearchTaskState() {
    std::lock_guard<std::mutex> lock(mutex_);
    return BuildTaskStateLocked();
}

std::vector<SearchResultView> MemoryToolEngine::GetSearchResults(int offset, int limit) {
    std::lock_guard<std::mutex> lock(mutex_);
    EnsureActiveSessionLocked();
    if (limit <= 0 || offset >= static_cast<int>(session_.results.size())) {
        return {};
    }

    const size_t start = static_cast<size_t>(std::max(offset, 0));
    const size_t end = std::min(session_.results.size(), start + static_cast<size_t>(limit));
    std::vector<SearchResultView> views;
    views.reserve(end - start);
    for (size_t index = start; index < end; ++index) {
        views.push_back(BuildSearchResultViewLocked(session_.results[index]));
    }
    return views;
}

std::vector<MemoryValuePreview> MemoryToolEngine::ReadMemoryValues(
    const std::vector<MemoryReadRequest>& requests) {
    std::lock_guard<std::mutex> lock(mutex_);
    EnsureActiveSessionLocked();
    if (!IsProcessAlive(session_.pid)) {
        session_.Clear();
        throw std::runtime_error("Search session target process is no longer available.");
    }

    ProcessMemoryReader reader(session_.pid);
    std::vector<MemoryValuePreview> previews;
    previews.reserve(requests.size());
    for (const MemoryReadRequest& request : requests) {
        const size_t length = ResolveValueByteLength(request.type, request.length);
        if (length == 0) {
            continue;
        }

        std::vector<uint8_t> buffer;
        if (!reader.Read(request.address, length, &buffer)) {
            continue;
        }

        MemoryValuePreview preview;
        preview.address = request.address;
        preview.type = request.type;
        preview.raw_bytes = buffer;
        preview.display_value =
            FormatDisplayValue(request.type, buffer, session_.little_endian);
        previews.push_back(std::move(preview));
    }
    return previews;
}

void MemoryToolEngine::FirstScan(int pid,
                                 const SearchValue& value,
                                 SearchMatchMode match_mode,
                                 bool /*scan_all_readable_regions*/) {
    if (match_mode != SearchMatchMode::kExact) {
        throw std::runtime_error("Only exact scan is supported.");
    }

    std::vector<uint8_t> pattern;
    std::string error;
    if (!BuildSearchPattern(value, &pattern, &error)) {
        throw std::runtime_error(error.empty() ? "Invalid search value." : error);
    }

    const SearchValueType value_type = value.type;
    const bool little_endian = value.little_endian;
    const uint64_t generation = [this, pid]() {
        std::lock_guard<std::mutex> lock(mutex_);
        session_.Clear();
        return StartTaskLocked(true, pid);
    }();

    std::thread([this, generation, pid, pattern = std::move(pattern), value_type, little_endian]() {
        try {
            if (!IsProcessAlive(pid)) {
                throw std::runtime_error("Target process is no longer available.");
            }

            std::vector<MemoryRegion> regions = ReadProcessRegions(pid, true, true, true);
            ProcessMemoryReader reader(pid);
            std::vector<SearchResultEntry> results = ::memory_tool::FirstScan(
                &reader,
                regions,
                pattern,
                value_type,
                [this, generation](const SearchScanProgress& progress) {
                    return UpdateTaskProgress(generation, progress);
                });

            const size_t result_count = results.size();
            SearchSession next_session;
            next_session.has_active_session = true;
            next_session.pid = pid;
            next_session.type = value_type;
            next_session.exact_mode = true;
            next_session.little_endian = little_endian;
            next_session.value_size = pattern.size();
            next_session.regions = std::move(regions);
            next_session.results = std::move(results);
            FinishTaskSuccess(generation, std::move(next_session), result_count);
        } catch (const std::exception& exception) {
            FinishTaskFailure(generation, exception.what());
        } catch (...) {
            FinishTaskFailure(generation, "Unexpected native scan failure.");
        }
    }).detach();
}

void MemoryToolEngine::NextScan(const SearchValue& value, SearchMatchMode match_mode) {
    if (match_mode != SearchMatchMode::kExact) {
        throw std::runtime_error("Only exact scan is supported.");
    }

    std::vector<uint8_t> pattern;
    std::string error;
    if (!BuildSearchPattern(value, &pattern, &error)) {
        throw std::runtime_error(error.empty() ? "Invalid search value." : error);
    }

    SearchSession session_snapshot;
    const uint64_t generation = [this, &session_snapshot, &value]() {
        std::lock_guard<std::mutex> lock(mutex_);
        EnsureTaskNotRunningLocked();
        EnsureActiveSessionLocked();
        if (!IsProcessAlive(session_.pid)) {
            session_.Clear();
            throw std::runtime_error("Search session target process is no longer available.");
        }
        if (value.type != session_.type) {
            throw std::runtime_error("Search value type does not match the active session.");
        }
        session_snapshot = session_;
        return StartTaskLocked(false, session_.pid);
    }();

    const bool little_endian = value.little_endian;

    std::thread([this,
                 generation,
                 session_snapshot = std::move(session_snapshot),
                 pattern = std::move(pattern),
                 little_endian]() mutable {
        try {
            ProcessMemoryReader reader(session_snapshot.pid);
            std::vector<SearchResultEntry> results = ::memory_tool::NextScan(
                &reader,
                session_snapshot.results,
                pattern,
                [this, generation](const SearchScanProgress& progress) {
                    return UpdateTaskProgress(generation, progress);
                });

            const size_t result_count = results.size();
            session_snapshot.results = std::move(results);
            session_snapshot.value_size = pattern.size();
            session_snapshot.little_endian = little_endian;
            FinishTaskSuccess(generation, std::move(session_snapshot), result_count);
        } catch (const std::exception& exception) {
            FinishTaskFailure(generation, exception.what());
        } catch (...) {
            FinishTaskFailure(generation, "Unexpected native scan failure.");
        }
    }).detach();
}

void MemoryToolEngine::CancelSearch() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (task_.view.status != SearchTaskStatus::kRunning) {
        return;
    }

    if (task_.cancel_flag) {
        task_.cancel_flag->store(true);
    }
    task_.view.status = SearchTaskStatus::kCancelled;
    task_.view.can_cancel = false;
    task_.view.elapsed_milliseconds = ElapsedMilliseconds(task_.started_at);
    task_.view.message = "Search cancelled.";
}

void MemoryToolEngine::ResetSearchSession() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (task_.cancel_flag) {
        task_.cancel_flag->store(true);
    }
    ++task_generation_counter_;
    task_ = SearchTaskRuntime{};
    session_.Clear();
}

SearchSessionStateView MemoryToolEngine::BuildSessionStateLocked() const {
    SearchSessionStateView state;
    state.has_active_session = session_.has_active_session;
    state.pid = session_.pid;
    state.type = session_.type;
    state.region_count = session_.regions.size();
    state.result_count = session_.results.size();
    state.exact_mode = session_.exact_mode;
    return state;
}

SearchTaskStateView MemoryToolEngine::BuildTaskStateLocked() const {
    SearchTaskStateView state = task_.view;
    if (state.status == SearchTaskStatus::kRunning || state.status == SearchTaskStatus::kCancelled) {
        state.elapsed_milliseconds = ElapsedMilliseconds(task_.started_at);
    }
    return state;
}

SearchResultView MemoryToolEngine::BuildSearchResultViewLocked(const SearchResultEntry& entry) const {
    SearchResultView view;
    view.address = entry.address;
    view.region_start = entry.region_start;
    view.type = session_.type;
    view.raw_bytes = entry.raw_bytes;
    view.display_value =
        FormatDisplayValue(session_.type, entry.raw_bytes, session_.little_endian);
    return view;
}

void MemoryToolEngine::EnsureActiveSessionLocked() const {
    if (!session_.has_active_session) {
        throw std::runtime_error("No active search session.");
    }
}

void MemoryToolEngine::EnsureTaskNotRunningLocked() const {
    if (task_.view.status == SearchTaskStatus::kRunning) {
        throw std::runtime_error("A search task is already running.");
    }
}

uint64_t MemoryToolEngine::StartTaskLocked(bool is_first_scan, int pid) {
    EnsureTaskNotRunningLocked();

    if (task_.cancel_flag) {
        task_.cancel_flag->store(true);
    }

    ++task_generation_counter_;
    task_ = SearchTaskRuntime{};
    task_.generation = task_generation_counter_;
    task_.started_at = std::chrono::steady_clock::now();
    task_.cancel_flag = std::make_shared<std::atomic_bool>(false);
    task_.view.status = SearchTaskStatus::kRunning;
    task_.view.is_first_scan = is_first_scan;
    task_.view.pid = pid;
    task_.view.can_cancel = true;
    task_.view.message = is_first_scan ? "First scan is running." : "Next scan is running.";
    return task_.generation;
}

bool MemoryToolEngine::UpdateTaskProgress(uint64_t generation, const SearchScanProgress& progress) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (task_.generation != generation || task_.view.status != SearchTaskStatus::kRunning) {
        return false;
    }
    if (task_.cancel_flag && task_.cancel_flag->load()) {
        return false;
    }

    task_.view.processed_region_count = progress.processed_region_count;
    task_.view.total_region_count = progress.total_region_count;
    task_.view.processed_entry_count = progress.processed_entry_count;
    task_.view.total_entry_count = progress.total_entry_count;
    task_.view.processed_byte_count = progress.processed_byte_count;
    task_.view.total_byte_count = progress.total_byte_count;
    task_.view.result_count = progress.result_count;
    task_.view.elapsed_milliseconds = ElapsedMilliseconds(task_.started_at);
    return true;
}

void MemoryToolEngine::FinishTaskSuccess(uint64_t generation,
                                         SearchSession&& next_session,
                                         size_t result_count) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (task_.generation != generation || task_.view.status != SearchTaskStatus::kRunning) {
        return;
    }
    if (task_.cancel_flag && task_.cancel_flag->load()) {
        return;
    }

    session_ = std::move(next_session);
    task_.view.status = SearchTaskStatus::kCompleted;
    task_.view.can_cancel = false;
    task_.view.result_count = result_count;
    task_.view.processed_region_count = task_.view.total_region_count;
    task_.view.processed_entry_count = task_.view.total_entry_count;
    task_.view.processed_byte_count = task_.view.total_byte_count;
    task_.view.elapsed_milliseconds = ElapsedMilliseconds(task_.started_at);
    task_.view.message = "Search completed.";
}

void MemoryToolEngine::FinishTaskFailure(uint64_t generation, const std::string& message) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (task_.generation != generation || task_.view.status != SearchTaskStatus::kRunning) {
        return;
    }

    task_.view.status = SearchTaskStatus::kFailed;
    task_.view.can_cancel = false;
    task_.view.elapsed_milliseconds = ElapsedMilliseconds(task_.started_at);
    task_.view.message = message;
}

}  // namespace memory_tool
