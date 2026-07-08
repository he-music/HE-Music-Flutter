import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../domain/entities/online_platform.dart';
import '../providers/online_providers.dart';

class ParseSourceUrlPage extends ConsumerStatefulWidget {
  const ParseSourceUrlPage({super.key});

  @override
  ConsumerState<ParseSourceUrlPage> createState() => _ParseSourceUrlPageState();
}

class _ParseSourceUrlPageState extends ConsumerState<ParseSourceUrlPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  SourceUrlParseResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final apiClient = ref.read(onlineApiClientProvider);
      final result = await apiClient.parseSourceUrl(text);
      if (!mounted) return;
      if (result.id.isEmpty || result.platform.isEmpty || result.type.isEmpty) {
        setState(() {
          _loading = false;
          _error = AppI18n.t(ref.read(appConfigProvider), 'parse.fail');
        });
        return;
      }
      setState(() {
        _loading = false;
        _result = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppI18n.t(ref.read(appConfigProvider), 'parse.fail');
      });
    }
  }

  void _navigateToDetail() {
    final result = _result;
    if (result == null) return;

    final route = switch (result.type) {
      'song' => AppRoutes.songDetail,
      'playlist' => AppRoutes.playlistDetail,
      'album' => AppRoutes.albumDetail,
      'artist' => AppRoutes.artistDetail,
      'mv' => AppRoutes.videoDetail,
      _ => null,
    };
    if (route == null) return;

    context.push(
      Uri(
        path: route,
        queryParameters: <String, String>{
          'id': result.id,
          'platform': result.platform,
        },
      ).toString(),
    );
  }

  String _typeName(String type, String localeCode) {
    return switch (type) {
      'song' => AppI18n.tByLocaleCode(localeCode, 'search.type.song'),
      'playlist' => AppI18n.tByLocaleCode(localeCode, 'search.type.playlist'),
      'album' => AppI18n.tByLocaleCode(localeCode, 'search.type.album'),
      'artist' => AppI18n.tByLocaleCode(localeCode, 'search.type.artist'),
      'mv' => AppI18n.tByLocaleCode(localeCode, 'search.type.video'),
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final platforms =
        ref.watch(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final theme = Theme.of(context);
    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'parse.title')),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 输入框
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: AppI18n.t(config, 'parse.placeholder'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 解析按钮
                FilledButton(
                  onPressed: _loading ? null : _parse,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppI18n.t(config, 'common.parse')),
                ),
                const SizedBox(height: 16),
                // 结果区域
                _buildResultArea(theme, config.localeCode, platforms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultArea(
    ThemeData theme,
    String localeCode,
    List<OnlinePlatform> platforms,
  ) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    final platformName = _platformDisplayName(result.platform, platforms);

    return Card(
      child: ListTile(
        title: Text('$platformName  ·  ${_typeName(result.type, localeCode)}'),
        subtitle: Text('ID: ${result.id}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _navigateToDetail,
      ),
    );
  }

  String _platformDisplayName(
    String platformId,
    List<OnlinePlatform> platforms,
  ) {
    final shortName = platforms
        .where((platform) => platform.id == platformId)
        .firstOrNull
        ?.shortName
        .trim();
    return shortName == null || shortName.isEmpty ? platformId : shortName;
  }
}
