import 'package:pigeon/pigeon.dart';

enum SearchValueType { i8, i16, i32, i64, f32, f64, bytes }

enum SearchMatchMode { exact }

enum SearchTaskStatus { idle, running, completed, cancelled, failed }

class ProcessInfo {
  final int pid;
  final String name;
  final String packageName;
  final Uint8List? icon;

  const ProcessInfo({
    required this.pid,
    required this.packageName,
    required this.name,
    this.icon,
  });
}

class SearchValue {
  final SearchValueType type;
  final String? textValue;
  final Uint8List? bytesValue;
  final bool littleEndian;

  const SearchValue({
    required this.type,
    this.textValue,
    this.bytesValue,
    required this.littleEndian,
  });
}

class MemoryRegion {
  final int startAddress;
  final int endAddress;
  final String perms;
  final int size;
  final String? path;
  final bool isAnonymous;

  const MemoryRegion({
    required this.startAddress,
    required this.endAddress,
    required this.perms,
    required this.size,
    this.path,
    required this.isAnonymous,
  });
}

class MemoryRegionQuery {
  final int pid;
  final int offset;
  final int limit;
  final bool readableOnly;
  final bool includeAnonymous;
  final bool includeFileBacked;

  const MemoryRegionQuery({
    required this.pid,
    required this.offset,
    required this.limit,
    required this.readableOnly,
    required this.includeAnonymous,
    required this.includeFileBacked,
  });
}

class FirstScanRequest {
  final int pid;
  final SearchValue value;
  final SearchMatchMode matchMode;
  final bool scanAllReadableRegions;

  const FirstScanRequest({
    required this.pid,
    required this.value,
    required this.matchMode,
    required this.scanAllReadableRegions,
  });
}

class NextScanRequest {
  final SearchValue value;
  final SearchMatchMode matchMode;

  const NextScanRequest({required this.value, required this.matchMode});
}

class SearchResult {
  final int address;
  final int regionStart;
  final SearchValueType type;
  final Uint8List rawBytes;
  final String displayValue;

  const SearchResult({
    required this.address,
    required this.regionStart,
    required this.type,
    required this.rawBytes,
    required this.displayValue,
  });
}

class MemoryReadRequest {
  final int address;
  final SearchValueType type;
  final int length;

  const MemoryReadRequest({
    required this.address,
    required this.type,
    required this.length,
  });
}

class MemoryValuePreview {
  final int address;
  final SearchValueType type;
  final Uint8List rawBytes;
  final String displayValue;

  const MemoryValuePreview({
    required this.address,
    required this.type,
    required this.rawBytes,
    required this.displayValue,
  });
}

class SearchSessionState {
  final bool hasActiveSession;
  final int pid;
  final SearchValueType type;
  final int regionCount;
  final int resultCount;
  final bool exactMode;

  const SearchSessionState({
    required this.hasActiveSession,
    required this.pid,
    required this.type,
    required this.regionCount,
    required this.resultCount,
    required this.exactMode,
  });
}

class SearchTaskState {
  final SearchTaskStatus status;
  final bool isFirstScan;
  final int pid;
  final int processedRegions;
  final int totalRegions;
  final int processedEntries;
  final int totalEntries;
  final int processedBytes;
  final int totalBytes;
  final int resultCount;
  final int elapsedMilliseconds;
  final bool canCancel;
  final String message;

  const SearchTaskState({
    required this.status,
    required this.isFirstScan,
    required this.pid,
    required this.processedRegions,
    required this.totalRegions,
    required this.processedEntries,
    required this.totalEntries,
    required this.processedBytes,
    required this.totalBytes,
    required this.resultCount,
    required this.elapsedMilliseconds,
    required this.canCancel,
    required this.message,
  });
}

@HostApi()
abstract class MemoryToolNative {
  @async
  int getPid({required String packageName});

  @async
  List<ProcessInfo> getProcessInfo(int offset, int limit);

  @async
  List<MemoryRegion> getMemoryRegions(MemoryRegionQuery query);

  @async
  SearchSessionState getSearchSessionState();

  @async
  SearchTaskState getSearchTaskState();

  @async
  List<SearchResult> getSearchResults(int offset, int limit);

  @async
  List<MemoryValuePreview> readMemoryValues(List<MemoryReadRequest> requests);

  @async
  void firstScan(FirstScanRequest request);

  @async
  void nextScan(NextScanRequest request);

  @async
  void cancelSearch();

  @async
  void resetSearchSession();
}
