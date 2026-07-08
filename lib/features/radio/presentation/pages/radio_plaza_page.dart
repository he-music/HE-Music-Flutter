import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../features/player/domain/entities/player_queue_source.dart';
import '../../../../features/player/domain/entities/player_track.dart';
import '../../../../features/player/presentation/providers/player_providers.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/plaza_widgets.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../controllers/radio_plaza_controller.dart';
import '../providers/radio_providers.dart';

class RadioPlazaPage extends ConsumerStatefulWidget {
  const RadioPlazaPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<RadioPlazaPage> createState() => _RadioPlazaPageState();
}

class _RadioPlazaPageState extends ConsumerState<RadioPlazaPage> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(onlinePlatformsProvider);
    final state = ref.watch(radioPlazaControllerProvider);
    final config = ref.watch(appConfigProvider);

    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'radio.plaza.title')),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: platformsAsync.when(
                data: (platforms) {
                  final supportedPlatforms = _supportedPlatforms(platforms);
                  _initializeIfNeeded(supportedPlatforms);
                  return OnlinePlatformTabs(
                    platforms: supportedPlatforms,
                    selectedId: state.selectedPlatformId,
                    requiredFeatureFlag: PlatformFeatureSupportFlag.listRadios,
                    onSelected: (id) => ref
                        .read(radioPlazaControllerProvider.notifier)
                        .selectPlatform(id),
                  );
                },
                loading: () => const PlazaPlatformTabsSkeleton(),
                error: (error, _) => PlazaPlatformsErrorView(
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                  i18nKey: 'radio.platform_load_failed',
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: platformsAsync.when(
                data: (platforms) {
                  final supportedPlatforms = _supportedPlatforms(platforms);
                  if (supportedPlatforms.isEmpty) {
                    return _EmptyState(
                      label: AppI18n.t(config, 'radio.plaza.empty'),
                    );
                  }
                  return _RadioPlazaBody(
                    state: state,
                    onRetry: () =>
                        ref.read(radioPlazaControllerProvider.notifier).retry(),
                    onSelectGroup: (groupName) => ref
                        .read(radioPlazaControllerProvider.notifier)
                        .selectGroup(groupName),
                    onTapRadio: _handleRadioTap,
                  );
                },
                loading: () => const _RadioPlazaLoadingView(),
                error: (error, _) => PlazaErrorView(
                  message: '$error',
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OnlinePlatform> _supportedPlatforms(List<OnlinePlatform> platforms) {
    return platforms
        .where(
          (platform) =>
              platform.available &&
              platform.supports(PlatformFeatureSupportFlag.listRadios),
        )
        .toList(growable: false);
  }

  void _initializeIfNeeded(List<OnlinePlatform> platforms) {
    if (_initialized || platforms.isEmpty) {
      return;
    }
    _initialized = true;
    final initialPlatformId = _resolveInitialPlatform(platforms);
    if (initialPlatformId == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(radioPlazaControllerProvider.notifier)
          .initialize(initialPlatformId);
    });
  }

  String? _resolveInitialPlatform(List<OnlinePlatform> platforms) {
    final preferred = widget.initialPlatform?.trim() ?? '';
    if (preferred.isNotEmpty) {
      for (final platform in platforms) {
        if (platform.id == preferred) {
          return preferred;
        }
      }
    }
    if (platforms.isEmpty) {
      return null;
    }
    return platforms.first.id;
  }

  Future<void> _handleRadioTap(RadioInfo radio) async {
    final config = ref.read(appConfigProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final playerState = ref.read(playerControllerProvider);
    final radioId = radio.id.trim();
    final radioPlatform = radio.platform.trim();
    if (radioId.isEmpty || radioPlatform.isEmpty) {
      AppMessageService.showError(AppI18n.t(config, 'radio.play_failed'));
      return;
    }
    if (playerState.isRadioMode &&
        playerState.currentRadioId == radioId &&
        playerState.currentRadioPlatform == radioPlatform &&
        playerState.currentRadioPageIndex == 1) {
      try {
        await playerController.togglePlayPause();
      } catch (error) {
        if (!mounted) {
          return;
        }
        AppMessageService.showError('$error');
      }
      return;
    }
    try {
      final songs = await ref
          .read(radioPlazaControllerProvider.notifier)
          .fetchSongs(id: radioId, platform: radioPlatform, pageIndex: 1);
      if (songs.isEmpty) {
        if (!mounted) {
          return;
        }
        AppMessageService.showError(AppI18n.t(config, 'radio.song_empty'));
        return;
      }
      final tracks = songs.map(_buildTrack).toList(growable: false);
      await playerController.replaceQueue(
        tracks,
        queueSource: PlayerQueueSource(
          routePath: AppRoutes.radioPlaza,
          queryParameters: <String, String>{'platform': radioPlatform},
          title: radio.name,
        ),
        isRadioMode: true,
        currentRadioId: radioId,
        currentRadioPlatform: radioPlatform,
        currentRadioPageIndex: 1,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError('$error');
    }
  }

  PlayerTrack _buildTrack(SongInfo song) {
    final platformId = song.platform.trim();
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final coverUrl = resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: platformId,
      songId: song.id,
      cover: song.cover,
      size: 300,
    );
    final localPath = song.path?.trim();
    return PlayerTrack(
      id: song.id,
      title: song.title,
      path: localPath == null || localPath.isEmpty ? null : localPath,
      duration: song.duration > 0
          ? Duration(milliseconds: song.duration)
          : null,
      links: song.links,
      artist: song.artist,
      albumId: song.album?.id,
      album: song.album?.name,
      artists: song.artists,
      mvId: song.mvId,
      artworkUrl: coverUrl.isEmpty ? null : coverUrl,
      platform: platformId,
    );
  }
}

class _RadioPlazaBody extends ConsumerWidget {
  const _RadioPlazaBody({
    required this.state,
    required this.onRetry,
    required this.onSelectGroup,
    required this.onTapRadio,
  });

  final RadioPlazaState state;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<RadioInfo> onTapRadio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.groups.isEmpty) {
      return const _RadioPlazaLoadingView();
    }
    if (state.errorMessage != null && state.groups.isEmpty) {
      return PlazaErrorView(message: state.errorMessage!, onRetry: onRetry);
    }
    final groups = state.availableGroups;
    if (groups.isEmpty) {
      final config = ref.read(appConfigProvider);
      return _EmptyState(label: AppI18n.t(config, 'radio.empty'));
    }
    final selectedGroup = state.selectedGroup;
    if (selectedGroup == null) {
      final config = ref.read(appConfigProvider);
      return _EmptyState(label: AppI18n.t(config, 'radio.empty'));
    }
    return Column(
      children: <Widget>[
        _GroupTabs(
          groups: groups,
          selectedGroupName: selectedGroup.name,
          onSelected: onSelectGroup,
        ),
        const Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(
          child: _RadioGrid(
            radios: selectedGroup.radios,
            onTapRadio: onTapRadio,
          ),
        ),
      ],
    );
  }
}

class _GroupTabs extends StatefulWidget {
  const _GroupTabs({
    required this.groups,
    required this.selectedGroupName,
    required this.onSelected,
  });

  final List<RadioGroupInfo> groups;
  final String selectedGroupName;
  final ValueChanged<String> onSelected;

  @override
  State<_GroupTabs> createState() => _GroupTabsState();
}

class _GroupTabsState extends State<_GroupTabs> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _chipKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureSelectedChipVisible();
    });
  }

  @override
  void didUpdateWidget(covariant _GroupTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGroupName != widget.selectedGroupName ||
        oldWidget.groups != widget.groups) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _ensureSelectedChipVisible();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedSelectedGroupName = widget.selectedGroupName.trim();

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.groups
                .map((group) {
                  final normalizedGroupName = group.name.trim();
                  final groupName = normalizedGroupName.isEmpty
                      ? '-'
                      : normalizedGroupName;
                  final selected =
                      normalizedGroupName == normalizedSelectedGroupName;
                  return Padding(
                    key: _keyForGroup(normalizedGroupName),
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(groupName),
                      showCheckmark: false,
                      selectedColor: colorScheme.primary.withValues(
                        alpha: 0.10,
                      ),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      side: BorderSide(
                        color: selected
                            ? colorScheme.primary.withValues(alpha: 0.30)
                            : colorScheme.outlineVariant,
                      ),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      visualDensity: VisualDensity.compact,
                      selected: selected,
                      onSelected: (_) => widget.onSelected(group.name),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  GlobalKey _keyForGroup(String groupName) {
    return _chipKeys.putIfAbsent(groupName, () => GlobalKey());
  }

  void _ensureSelectedChipVisible() {
    final selectedGroupName = widget.selectedGroupName.trim();
    if (selectedGroupName.isEmpty) {
      return;
    }
    final targetContext = _chipKeys[selectedGroupName]?.currentContext;
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }
}

class _RadioGrid extends ConsumerWidget {
  const _RadioGrid({required this.radios, required this.onTapRadio});

  final List<RadioInfo> radios;
  final ValueChanged<RadioInfo> onTapRadio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (radios.isEmpty) {
      final config = ref.read(appConfigProvider);
      return _EmptyState(label: AppI18n.t(config, 'radio.empty'));
    }
    final playerState = ref.watch(playerControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = resolveAdaptiveMediaGridSpec(
          maxWidth: constraints.maxWidth - 24,
        );
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          gridDelegate: spec.sliverDelegate,
          itemCount: radios.length,
          itemBuilder: (context, index) {
            final radio = radios[index];
            final isPlaying =
                playerState.isRadioMode &&
                playerState.currentRadioId == radio.id.trim() &&
                playerState.currentRadioPlatform == radio.platform.trim();
            return MediaGridCard(
              kind: MediaGridCardKind.playlist,
              title: radio.name,
              subtitle: '',
              coverUrl: radio.cover,
              selected: isPlaying,
              showCenterPlayIcon: isPlaying,
              onTap: () => onTapRadio(radio),
            );
          },
        );
      },
    );
  }
}

class _RadioPlazaLoadingView extends StatelessWidget {
  const _RadioPlazaLoadingView();

  @override
  Widget build(BuildContext context) {
    return const PlazaGridSkeleton();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
