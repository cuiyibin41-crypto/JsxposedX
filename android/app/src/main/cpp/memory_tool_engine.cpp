#include "memory_tool_engine.h"

#include <algorithm>
#include <iterator>
#include <stdexcept>
#include <thread>
#include <utility>

#include "memory_tool_reader.h"
#include "memory_tool_regions.h"
#include "memory_tool_value.h"

namespace memory_tool {

namespace {

constexpr size_t kMaxParallelFirstScanWorkers = 6;

uint64_t ElapsedMilliseconds(const std::chrono::steady_clock::time_point& started_at) {
    if (started_at == std::chrono::steady_clock::time_point{}) {
        return 0;
    }
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
                                     std::chrono::steady_clock::now() - started_at)
                                     .count());
}

const MemoryRegion* FindRegionByStart(const std::vector<MemoryRegion>& regions,
                                      uint64_t region_start) {
    const auto iterator = std::find_if(regions.begin(), regions.end(), [region_start](const MemoryRegion& region) {
        return region.start_address == region_start;
    });
    if (iterator == regions.end()) {
        return nullptr;
    }
    return &(*iterator);
}

std::vector<MemoryRegion> FilterRegionsByTypeKeys(const std::vector<MemoryRegion>& regions,
                                                  const std::vector<std::string>& allowed_keys) {
    if (allowed_keys.empty()) {
        return regions;
    }

    std::vector<MemoryRegion> filtered;
    filtered.reserve(regions.size());
    for (const MemoryRegion& region : regions) {
        const std::string region_key = ClassifyMemoryRegion(region);
        if (std::find(allowed_keys.begin(), allowed_keys.end(), region_key) != allowed_keys.end()) {
            filtered.push_back(region);
        }
    }
    return filtered;
}

size_t ResolveFirstScanWorkerCount(size_t region_count) {
    if (region_count <= 1) {
        return region_count;
    }

    const unsigned int hardware_workers = std::thread::hardware_concurrency();
    const size_t preferred_workers = hardware_workers == 0 ? 4U : hardware_workers;
    return std::max<size_t>(
        1,
        std::min(region_count, std::min(preferred_workers, kMaxParallelFirstScanWorkers)));
}

std::vector<std::vector<MemoryRegion>> PartitionRegionsForWorkers(
    const std::vector<MemoryRegion>& regions,
    size_t worker_count) {
    if (worker_count <= 1) {
        return {regions};
    }

    std::vector<std::vector<MemoryRegion>> buckets(worker_count);
    std::vector<uint64_t> bucket_sizes(worker_count, 0);
    for (const MemoryRegion& region : regions) {
        const auto iterator =
            std::min_element(bucket_sizes.begin(), bucket_sizes.end());
        const size_t bucket_index =
            static_cast<size_t>(std::distance(bucket_sizes.begin(), iterator));
        buckets[bucket_index].push_back(region);
        bucket_sizes[bucket_index] += region.size;
    }
    return buckets;
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
        preview.display_value = FormatDisplayValue(request.type,
                                                   buffer,
                                                   session_.little_endian,
                                                   request.type == SearchValueType::kBytes &&
                                                       session_.bytes_display_as_text);
        previews.push_back(std::move(preview));
    }
    return previews;
}

void MemoryToolEngine::FirstScan(int pid,
                                 const SearchValue& value,
                                 SearchMatchMode match_mode,
                                 const std::vector<std::string>& range_section_keys,
                                 bool scan_all_readable_regions) {
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
    const bool bytes_display_as_text = ShouldDisplayBytesAsText(value);
    const uint64_t generation = [this, pid]() {
        std::lock_guard<std::mutex> lock(mutex_);
        session_.Clear();
        return StartTaskLocked(true, pid);
    }();

    std::thread([this,
                 generation,
                 pid,
                 pattern = std::move(pattern),
                 value_type,
                 little_endian,
                 bytes_display_as_text,
                 range_section_keys,
                 scan_all_readable_regions]() {
        try {
            if (!IsProcessAlive(pid)) {
                throw std::runtime_error("Target process is no longer available.");
            }

            std::vector<MemoryRegion> regions = ReadProcessRegions(pid, true, true, true);
            if (!scan_all_readable_regions) {
                regions = FilterRegionsByTypeKeys(regions, range_section_keys);
            }
            uint64_t total_byte_count = 0;
            for (const MemoryRegion& region : regions) {
                total_byte_count += region.size;
            }
            const size_t worker_count = ResolveFirstScanWorkerCount(regions.size());
            const std::vector<std::vector<MemoryRegion>> region_buckets =
                PartitionRegionsForWorkers(regions, worker_count);

            std::atomic_size_t processed_region_count{0};
            std::atomic_uint64_t processed_byte_count{0};
            std::atomic_size_t aggregated_result_count{0};
            std::atomic_bool should_stop{false};
            std::mutex progress_mutex;
            std::vector<std::vector<SearchResultEntry>> worker_results(region_buckets.size());
            std::vector<std::thread> workers;
            workers.reserve(region_buckets.size());

            const auto report_progress = [this,
                                          generation,
                                          &regions,
                                          &processed_region_count,
                                          &processed_byte_count,
                                          &aggregated_result_count,
                                          &should_stop,
                                          &progress_mutex,
                                          total_byte_count]() {
                std::lock_guard<std::mutex> lock(progress_mutex);
                if (should_stop.load()) {
                    return false;
                }

                SearchScanProgress progress;
                progress.total_region_count = regions.size();
                progress.total_byte_count = total_byte_count;
                progress.processed_region_count = processed_region_count.load();
                progress.processed_byte_count = processed_byte_count.load();
                progress.result_count = aggregated_result_count.load();

                if (!UpdateTaskProgress(generation, progress)) {
                    should_stop.store(true);
                    return false;
                }
                return true;
            };

            for (size_t index = 0; index < region_buckets.size(); ++index) {
                if (region_buckets[index].empty()) {
                    continue;
                }

                workers.emplace_back([&pattern,
                                      &region_buckets,
                                      &worker_results,
                                      &processed_region_count,
                                      &processed_byte_count,
                                      &aggregated_result_count,
                                      &report_progress,
                                      &should_stop,
                                      index,
                                      pid,
                                      value_type]() {
                    ProcessMemoryReader reader(pid);
                    SearchScanProgress local_progress;
                    worker_results[index] = ::memory_tool::FirstScan(
                        &reader,
                        region_buckets[index],
                        pattern,
                        value_type,
                        [&](const SearchScanProgress& progress) {
                            if (should_stop.load()) {
                                return false;
                            }

                            processed_region_count.fetch_add(progress.processed_region_count -
                                                             local_progress.processed_region_count);
                            processed_byte_count.fetch_add(progress.processed_byte_count -
                                                           local_progress.processed_byte_count);
                            aggregated_result_count.fetch_add(progress.result_count -
                                                              local_progress.result_count);
                            local_progress = progress;
                            return report_progress();
                        });
                });
            }

            for (std::thread& worker : workers) {
                if (worker.joinable()) {
                    worker.join();
                }
            }

            if (should_stop.load()) {
                return;
            }

            std::vector<SearchResultEntry> results;
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
            std::sort(results.begin(),
                      results.end(),
                      [](const SearchResultEntry& left, const SearchResultEntry& right) {
                          if (left.region_start != right.region_start) {
                              return left.region_start < right.region_start;
                          }
                          return left.address < right.address;
                      });

            SearchSession next_session;
            next_session.has_active_session = true;
            next_session.pid = pid;
            next_session.type = value_type;
            next_session.exact_mode = true;
            next_session.little_endian = little_endian;
            next_session.bytes_display_as_text = bytes_display_as_text;
            next_session.value_size = pattern.size();
            next_session.current_value_bytes = pattern;
            next_session.current_display_value = FormatDisplayValue(
                value_type, pattern, little_endian, bytes_display_as_text);
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
    const bool bytes_display_as_text = ShouldDisplayBytesAsText(value);

    std::thread([this,
                 generation,
                 session_snapshot = std::move(session_snapshot),
                 pattern = std::move(pattern),
                 little_endian,
                 bytes_display_as_text]() mutable {
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
            session_snapshot.bytes_display_as_text = bytes_display_as_text;
            session_snapshot.current_value_bytes = pattern;
            session_snapshot.current_display_value = FormatDisplayValue(
                session_snapshot.type,
                pattern,
                little_endian,
                bytes_display_as_text);
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
    if (const MemoryRegion* region = FindRegionByStart(session_.regions, entry.region_start);
        region != nullptr) {
        view.region_type_key = ClassifyMemoryRegion(*region);
    } else {
        view.region_type_key = "other";
    }
    view.type = session_.type;
    view.raw_bytes = session_.current_value_bytes;
    view.display_value = session_.current_display_value;
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
