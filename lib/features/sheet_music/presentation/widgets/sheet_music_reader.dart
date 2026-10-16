import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../app/i18n/app_i18n.dart';
import 'sheet_music_loading.dart';
import '../../../../shared/widgets/app_network_image.dart';

/// 画廊负责缩放和拖拽手势；这里仅连接曲谱页码、全屏与保存操作。
class SheetMusicReader extends StatefulWidget {
  const SheetMusicReader({
    required this.pageUrls,
    required this.title,
    required this.locale,
    this.initialPage = 0,
    this.fullscreen = false,
    this.initialFitPage = true,
    this.onFitPageChanged,
    this.onPageChanged,
    this.currentPageActionBuilder,
    this.trailingAction,
    this.downloadStatus,
    super.key,
  });

  final List<String> pageUrls;
  final String title;
  final String locale;
  final int initialPage;
  final bool fullscreen;
  final bool initialFitPage;
  final ValueChanged<bool>? onFitPageChanged;
  final ValueChanged<int>? onPageChanged;
  final Widget Function(int pageIndex)? currentPageActionBuilder;
  final Widget? trailingAction;
  final Widget? downloadStatus;

  @override
  State<SheetMusicReader> createState() => _SheetMusicReaderState();
}

class _SheetMusicReaderState extends State<SheetMusicReader> {
  late int _page = widget.initialPage.clamp(0, widget.pageUrls.length - 1);
  late final PageController _controller = PageController(initialPage: _page);
  late bool _fitPage = widget.initialFitPage;
  bool _showControls = true;
  int _imageRevision = 0;

  String _label(String key) => AppI18n.tByLocaleCode(widget.locale, key);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 ||
        index >= widget.pageUrls.length ||
        !_controller.hasClients) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openFullscreen() async {
    var selected = _page;
    var fitPage = _fitPage;
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierLabel: 'sheet-music-reader',
      barrierColor: Colors.black,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => SheetMusicReader(
        pageUrls: widget.pageUrls,
        title: widget.title,
        locale: widget.locale,
        initialPage: selected,
        fullscreen: true,
        initialFitPage: fitPage,
        onFitPageChanged: (value) => fitPage = value,
        onPageChanged: (index) => selected = index,
        currentPageActionBuilder: widget.currentPageActionBuilder,
        downloadStatus: widget.downloadStatus,
      ),
    );
    if (!mounted) return;
    if (fitPage != _fitPage) {
      _changeFit(fitPage, page: selected);
    } else {
      _controller.jumpToPage(selected);
    }
  }

  Future<void> _showPages() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      builder: (context) => Column(
        children: [
          ListTile(
            title: Text(_label('sheet_music.choose_page')),
            trailing: IconButton(
              tooltip: _label('common.close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: widget.pageUrls.length,
              itemBuilder: (context, index) => Semantics(
                selected: index == _page,
                child: InkWell(
                  key: ValueKey('sheet-thumbnail-$index'),
                  onTap: () => Navigator.of(context).pop(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: index == _page ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: AppNetworkImage(
                            url: widget.pageUrls[index],
                            fit: BoxFit.contain,
                            cacheWidth: 220,
                            fallback: const Center(
                              child: Icon(Icons.image_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${index + 1}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted && selected != null) _goToPage(selected);
  }

  Widget _navigation() {
    final pageLabel = '${_page + 1} / ${widget.pageUrls.length}';
    final semanticLabel = AppI18n.formatByLocaleCode(
      widget.locale,
      'sheet_music.page',
      {'current': '${_page + 1}', 'total': '${widget.pageUrls.length}'},
    );
    final color = widget.fullscreen
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.12), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: widget.fullscreen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('sheet-fit-toggle'),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      textStyle: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: () => _changeFit(!_fitPage),
                    child: Text(
                      _label(
                        _fitPage
                            ? 'sheet_music.fit_reading'
                            : 'sheet_music.fit_page',
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                iconSize: 20,
                color: color,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: _label('sheet_music.previous_page'),
                onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
              ),
              Semantics(
                label: semanticLabel,
                liveRegion: true,
                child: Tooltip(
                  message: _label('sheet_music.choose_page'),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      textStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                      minimumSize: const Size(60, 44),
                    ),
                    onPressed: _showPages,
                    child: Text(
                      pageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                iconSize: 20,
                color: color,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: _label('sheet_music.next_page'),
                onPressed: _page < widget.pageUrls.length - 1
                    ? () => _goToPage(_page + 1)
                    : null,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: widget.fullscreen ? null : widget.trailingAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeFit(bool fitPage, {int? page}) {
    setState(() => _fitPage = fitPage);
    widget.onFitPageChanged?.call(fitPage);
    _reloadGallery(page ?? _page);
  }

  void _reloadGallery(int page) {
    setState(() => _imageRevision++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(page);
    });
  }

  Future<void> _retryImage(int index) async {
    await NetworkImage(widget.pageUrls[index]).evict();
    if (!mounted) return;
    _reloadGallery(_page);
  }

  @override
  Widget build(BuildContext context) {
    final gallery = KeyedSubtree(
      key: ValueKey(_imageRevision),
      child: PhotoViewGallery.builder(
        key: ValueKey(
          widget.fullscreen ? 'sheet-fullscreen-pager' : 'sheet-reader-pager',
        ),
        pageController: _controller,
        itemCount: widget.pageUrls.length,
        backgroundDecoration: BoxDecoration(
          color: widget.fullscreen ? Colors.black : Colors.transparent,
        ),
        onPageChanged: (index) {
          setState(() => _page = index);
          widget.onPageChanged?.call(index);
        },
        loadingBuilder: (context, progress) =>
            SheetMusicImageSkeleton(label: _label('sheet_music.loading')),
        builder: (context, index) => PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(widget.pageUrls[index]),
          semanticLabel: AppI18n.formatByLocaleCode(
            widget.locale,
            'sheet_music.page',
            {'current': '${index + 1}', 'total': '${widget.pageUrls.length}'},
          ),
          initialScale: _fitPage
              ? PhotoViewComputedScale.contained
              : PhotoViewComputedScale.covered,
          basePosition: _fitPage ? Alignment.center : Alignment.topCenter,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.contained * 5,
          onTapUp: (_, _, _) {
            if (widget.fullscreen) {
              setState(() => _showControls = !_showControls);
            } else {
              _openFullscreen();
            }
          },
          errorBuilder: (context, error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, size: 40),
                const SizedBox(height: 12),
                Text(_label('sheet_music.image_failed')),
                TextButton(
                  onPressed: () => _retryImage(index),
                  child: Text(_label('common.retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final body = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goToPage(_page - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goToPage(_page + 1),
        if (widget.fullscreen)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: widget.fullscreen
            ? Stack(
                children: [
                  Positioned.fill(child: gallery),
                  if (_showControls) ...[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          color: const Color(0xCC000000),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: _label('common.close'),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (widget.currentPageActionBuilder != null)
                                    widget.currentPageActionBuilder!(_page),
                                ],
                              ),
                              if (widget.downloadStatus != null)
                                widget.downloadStatus!,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ColoredBox(
                        color: const Color(0xCC000000),
                        child: _navigation(),
                      ),
                    ),
                  ],
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      onTap: _openFullscreen,
                      child: Tooltip(
                        message: _label('sheet_music.fullscreen'),
                        child: gallery,
                      ),
                    ),
                  ),
                  _navigation(),
                ],
              ),
      ),
    );
    if (!widget.fullscreen) return body;
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(backgroundColor: Colors.black, body: body),
    );
  }
}
