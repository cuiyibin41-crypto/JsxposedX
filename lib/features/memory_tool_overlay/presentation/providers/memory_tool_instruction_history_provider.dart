import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolInstructionHistoryEntry {
  const MemoryToolInstructionHistoryEntry({
    required this.pid,
    required this.address,
    required this.previousBytes,
  });

  final int pid;
  final int address;
  final Uint8List previousBytes;
}

class MemoryToolInstructionHistoryState {
  const MemoryToolInstructionHistoryState({
    this.entriesByPid =
        const <int, Map<int, MemoryToolInstructionHistoryEntry>>{},
  });

  final Map<int, Map<int, MemoryToolInstructionHistoryEntry>> entriesByPid;

  MemoryToolInstructionHistoryState copyWith({
    Map<int, Map<int, MemoryToolInstructionHistoryEntry>>? entriesByPid,
  }) {
    return MemoryToolInstructionHistoryState(
      entriesByPid: entriesByPid ?? this.entriesByPid,
    );
  }
}

final memoryToolInstructionHistoryProvider = NotifierProvider<
  MemoryToolInstructionHistory,
  MemoryToolInstructionHistoryState
>(MemoryToolInstructionHistory.new);

class MemoryToolInstructionHistory
    extends Notifier<MemoryToolInstructionHistoryState> {
  @override
  MemoryToolInstructionHistoryState build() {
    return const MemoryToolInstructionHistoryState();
  }

  void record({
    required int pid,
    required int address,
    required Uint8List previousBytes,
  }) {
    final nextEntriesByPid = _copyEntriesByPid();
    nextEntriesByPid[pid] = <int, MemoryToolInstructionHistoryEntry>{
      ...(nextEntriesByPid[pid] ??
          const <int, MemoryToolInstructionHistoryEntry>{}),
      address: MemoryToolInstructionHistoryEntry(
        pid: pid,
        address: address,
        previousBytes: Uint8List.fromList(previousBytes),
      ),
    };
    state = state.copyWith(entriesByPid: nextEntriesByPid);
  }

  void remove({
    required int pid,
    required int address,
  }) {
    final currentEntries = state.entriesByPid[pid];
    if (currentEntries == null || !currentEntries.containsKey(address)) {
      return;
    }

    final nextEntriesByPid = _copyEntriesByPid();
    final nextEntries = <int, MemoryToolInstructionHistoryEntry>{
      ...currentEntries,
    }..remove(address);
    if (nextEntries.isEmpty) {
      nextEntriesByPid.remove(pid);
    } else {
      nextEntriesByPid[pid] = nextEntries;
    }
    state = state.copyWith(entriesByPid: nextEntriesByPid);
  }

  void clearProcess(int pid) {
    if (!state.entriesByPid.containsKey(pid)) {
      return;
    }
    final nextEntriesByPid = _copyEntriesByPid()..remove(pid);
    state = state.copyWith(entriesByPid: nextEntriesByPid);
  }

  void clear() {
    if (state.entriesByPid.isEmpty) {
      return;
    }
    state = const MemoryToolInstructionHistoryState();
  }

  Map<int, Map<int, MemoryToolInstructionHistoryEntry>> _copyEntriesByPid() {
    return <int, Map<int, MemoryToolInstructionHistoryEntry>>{
      for (final entry in state.entriesByPid.entries)
        entry.key: <int, MemoryToolInstructionHistoryEntry>{...entry.value},
    };
  }
}
