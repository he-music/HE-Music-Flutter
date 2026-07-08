import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../data/providers/radio_providers.dart';
import '../../domain/repositories/radio_repository.dart';
import '../providers/radio_providers.dart';

class RadioPlazaState {
  const RadioPlazaState({
    required this.selectedPlatformId,
    required this.selectedGroupName,
    required this.loading,
    required this.groups,
    this.errorMessage,
  });

  final String? selectedPlatformId;
  final String? selectedGroupName;
  final bool loading;
  final List<RadioGroupInfo> groups;
  final String? errorMessage;

  List<RadioGroupInfo> get availableGroups =>
      groups.where((group) => group.radios.isNotEmpty).toList(growable: false);

  RadioGroupInfo? get selectedGroup {
    final selectedName = selectedGroupName?.trim() ?? '';
    final available = availableGroups;
    if (available.isEmpty) {
      return null;
    }
    if (selectedName.isEmpty) {
      return available.first;
    }
    for (final group in available) {
      if (group.name.trim() == selectedName) {
        return group;
      }
    }
    return available.first;
  }

  RadioPlazaState copyWith({
    String? selectedPlatformId,
    String? selectedGroupName,
    bool? loading,
    List<RadioGroupInfo>? groups,
    String? errorMessage,
    bool clearSelectedGroupName = false,
    bool clearError = false,
  }) {
    return RadioPlazaState(
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      selectedGroupName: clearSelectedGroupName
          ? null
          : selectedGroupName ?? this.selectedGroupName,
      loading: loading ?? this.loading,
      groups: groups ?? this.groups,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = RadioPlazaState(
    selectedPlatformId: null,
    selectedGroupName: null,
    loading: false,
    groups: <RadioGroupInfo>[],
  );
}

class RadioPlazaController extends Notifier<RadioPlazaState> {
  final Map<String, List<RadioGroupInfo>> _groupCache =
      <String, List<RadioGroupInfo>>{};
  final Map<String, String> _selectedGroupCache = <String, String>{};

  @override
  RadioPlazaState build() {
    return RadioPlazaState.initial;
  }

  Future<void> initialize(String platformId) async {
    final currentPlatformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedPlatformId = platformId.trim();
    if (normalizedPlatformId.isEmpty) {
      return;
    }
    if (currentPlatformId == normalizedPlatformId &&
        (state.groups.isNotEmpty ||
            _groupCache.containsKey(normalizedPlatformId))) {
      return;
    }
    await selectPlatform(normalizedPlatformId);
  }

  Future<void> selectPlatform(String platformId) async {
    final normalizedPlatformId = platformId.trim();
    if (normalizedPlatformId.isEmpty) {
      return;
    }
    final cachedGroups = _groupCache[normalizedPlatformId];
    if (cachedGroups != null) {
      final selectedGroupName = _resolveSelectedGroupName(
        normalizedPlatformId,
        cachedGroups,
      );
      state = state.copyWith(
        selectedPlatformId: normalizedPlatformId,
        selectedGroupName: selectedGroupName,
        loading: false,
        groups: cachedGroups,
        clearError: true,
      );
      return;
    }
    state = state.copyWith(
      selectedPlatformId: normalizedPlatformId,
      loading: true,
      groups: const <RadioGroupInfo>[],
      clearSelectedGroupName: true,
      clearError: true,
    );
    try {
      final groups = await _repository.fetchGroups(
        platform: normalizedPlatformId,
      );
      _groupCache[normalizedPlatformId] = groups;
      final selectedGroupName = _resolveSelectedGroupName(
        normalizedPlatformId,
        groups,
      );
      state = state.copyWith(
        loading: false,
        groups: groups,
        selectedGroupName: selectedGroupName,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        groups: const <RadioGroupInfo>[],
        clearSelectedGroupName: true,
        errorMessage: '$error',
      );
    }
  }

  Future<void> selectGroup(String groupName) async {
    final normalizedPlatformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedGroupName = groupName.trim();
    if (normalizedPlatformId.isEmpty || normalizedGroupName.isEmpty) {
      return;
    }
    final selectedGroupName = _resolveSelectedGroupName(
      normalizedPlatformId,
      state.groups,
      preferredGroupName: normalizedGroupName,
    );
    if (selectedGroupName == null ||
        selectedGroupName == state.selectedGroupName) {
      return;
    }
    state = state.copyWith(
      selectedGroupName: selectedGroupName,
      clearError: true,
    );
  }

  Future<void> retry() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty) {
      return;
    }
    _groupCache.remove(platformId);
    await selectPlatform(platformId);
  }

  String? _resolveSelectedGroupName(
    String platformId,
    List<RadioGroupInfo> groups, {
    String? preferredGroupName,
  }) {
    final availableGroups = groups
        .where((group) => group.radios.isNotEmpty)
        .toList(growable: false);
    if (availableGroups.isEmpty) {
      _selectedGroupCache.remove(platformId);
      return null;
    }
    final preferred = preferredGroupName?.trim() ?? '';
    if (preferred.isNotEmpty) {
      for (final group in availableGroups) {
        if (group.name.trim() == preferred) {
          _selectedGroupCache[platformId] = group.name;
          return group.name;
        }
      }
    }
    final cached = _selectedGroupCache[platformId]?.trim() ?? '';
    if (cached.isNotEmpty) {
      for (final group in availableGroups) {
        if (group.name.trim() == cached) {
          _selectedGroupCache[platformId] = group.name;
          return group.name;
        }
      }
    }
    final fallback = availableGroups.first.name;
    _selectedGroupCache[platformId] = fallback;
    return fallback;
  }

  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) {
    return _repository.fetchSongs(
      id: id,
      platform: platform,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  RadioRepository get _repository => ref.read(radioRepositoryProvider);
}
