import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSavedInstructionPatch {
  const MemoryToolSavedInstructionPatch({
    required this.address,
    required this.instructionText,
  });

  final int address;
  final String instructionText;
}

class MemoryToolSavedInstructionPatchesState {
  const MemoryToolSavedInstructionPatchesState({
    this.patchesByPid =
        const <int, Map<int, MemoryToolSavedInstructionPatch>>{},
  });

  final Map<int, Map<int, MemoryToolSavedInstructionPatch>> patchesByPid;

  MemoryToolSavedInstructionPatchesState copyWith({
    Map<int, Map<int, MemoryToolSavedInstructionPatch>>? patchesByPid,
  }) {
    return MemoryToolSavedInstructionPatchesState(
      patchesByPid: patchesByPid ?? this.patchesByPid,
    );
  }
}

final memoryToolSavedInstructionPatchesProvider = NotifierProvider<
  MemoryToolSavedInstructionPatches,
  MemoryToolSavedInstructionPatchesState
>(MemoryToolSavedInstructionPatches.new);

class MemoryToolSavedInstructionPatches
    extends Notifier<MemoryToolSavedInstructionPatchesState> {
  @override
  MemoryToolSavedInstructionPatchesState build() {
    return const MemoryToolSavedInstructionPatchesState();
  }

  void saveOne({
    required int pid,
    required int address,
    required String instructionText,
  }) {
    final nextPatchesByPid = _copyPatchesByPid();
    nextPatchesByPid[pid] = <int, MemoryToolSavedInstructionPatch>{
      ...(nextPatchesByPid[pid] ??
          const <int, MemoryToolSavedInstructionPatch>{}),
      address: MemoryToolSavedInstructionPatch(
        address: address,
        instructionText: instructionText,
      ),
    };
    state = state.copyWith(patchesByPid: nextPatchesByPid);
  }

  void removeOne({
    required int pid,
    required int address,
  }) {
    final currentPatches = state.patchesByPid[pid];
    if (currentPatches == null || !currentPatches.containsKey(address)) {
      return;
    }

    final nextPatchesByPid = _copyPatchesByPid();
    final nextPatches = <int, MemoryToolSavedInstructionPatch>{
      ...currentPatches,
    }..remove(address);
    if (nextPatches.isEmpty) {
      nextPatchesByPid.remove(pid);
    } else {
      nextPatchesByPid[pid] = nextPatches;
    }
    state = state.copyWith(patchesByPid: nextPatchesByPid);
  }

  void clearProcess(int pid) {
    if (!state.patchesByPid.containsKey(pid)) {
      return;
    }

    final nextPatchesByPid = _copyPatchesByPid()..remove(pid);
    state = state.copyWith(patchesByPid: nextPatchesByPid);
  }

  Map<int, Map<int, MemoryToolSavedInstructionPatch>> _copyPatchesByPid() {
    return <int, Map<int, MemoryToolSavedInstructionPatch>>{
      for (final entry in state.patchesByPid.entries)
        entry.key: <int, MemoryToolSavedInstructionPatch>{...entry.value},
    };
  }
}
