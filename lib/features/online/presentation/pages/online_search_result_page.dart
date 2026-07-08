import 'package:flutter/material.dart';

import 'online_search_bars.dart';
import 'online_search_comprehensive_result.dart';
import 'online_search_models.dart';
import 'online_search_result_list.dart';

class OnlineSearchResultPage extends StatelessWidget {
  const OnlineSearchResultPage({
    required this.localeCode,
    required this.selectedType,
    required this.onTypeChanged,
    required this.loadingPlatforms,
    required this.platforms,
    required this.selectedPlatformId,
    required this.onPlatformChanged,
    required this.availableTypes,
    required this.loading,
    required this.results,
    required this.comprehensiveResult,
    required this.error,
    required this.initialLoading,
    required this.likedSongKeys,
    required this.onTapItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
    required this.onMoreSection,
    required this.onLoadMore,
    required this.loadingMore,
    required this.hasMore,
    super.key,
  });

  final String localeCode;
  final SearchType selectedType;
  final ValueChanged<SearchType> onTypeChanged;
  final bool loadingPlatforms;
  final List<SearchPlatform> platforms;
  final String selectedPlatformId;
  final ValueChanged<String> onPlatformChanged;
  final List<SearchType> availableTypes;
  final bool loading;
  final List<Map<String, dynamic>> results;
  final OnlineComprehensiveSearchResult? comprehensiveResult;
  final String? error;
  final bool initialLoading;
  final Set<String> likedSongKeys;
  final void Function(SearchType type, Map<String, dynamic> item) onTapItem;
  final Future<void> Function(Map<String, dynamic>) onLikeSongItem;
  final ValueChanged<Map<String, dynamic>> onMoreSongItem;
  final ValueChanged<SearchType> onMoreSection;
  final Future<void> Function() onLoadMore;
  final bool loadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SearchTypeBar(
          localeCode: localeCode,
          selectedType: selectedType,
          types: availableTypes,
          onChanged: onTypeChanged,
        ),
        const SizedBox(height: 10),
        SearchPlatformBar(
          loading: loadingPlatforms,
          platforms: platforms,
          requiredFeatureFlag: selectedType.requiredPlatformFeatureFlag,
          selectedPlatformId: selectedPlatformId,
          onChanged: onPlatformChanged,
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 2),
        Expanded(
          child: selectedType == SearchType.comprehensive
              ? _buildComprehensive()
              : OnlineSearchResultList(
                  type: selectedType,
                  results: results,
                  error: error,
                  initialLoading: initialLoading,
                  likedSongKeys: likedSongKeys,
                  onTapItem: (item) => onTapItem(selectedType, item),
                  onLikeSongItem: onLikeSongItem,
                  onMoreSongItem: onMoreSongItem,
                  onLoadMore: onLoadMore,
                  loadingMore: loadingMore,
                  hasMore: hasMore,
                ),
        ),
      ],
    );
  }

  Widget _buildComprehensive() {
    if (error != null) {
      return Builder(
        builder: (context) => Center(
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final result = comprehensiveResult;
    if (result == null) {
      return const SizedBox.shrink();
    }
    return OnlineSearchComprehensiveResult(
      result: result,
      likedSongKeys: likedSongKeys,
      onTapItem: onTapItem,
      onLikeSongItem: onLikeSongItem,
      onMoreSongItem: onMoreSongItem,
      onMoreSection: onMoreSection,
    );
  }
}
