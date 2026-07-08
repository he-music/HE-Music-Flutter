import 'package:flutter/material.dart';

class OnlineSearchSuggestPanel extends StatelessWidget {
  const OnlineSearchSuggestPanel({
    required this.loading,
    required this.suggestions,
    required this.onTapKeyword,
    super.key,
  });

  final bool loading;
  final List<String> suggestions;
  final ValueChanged<String> onTapKeyword;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final displayed = suggestions.take(18).toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemCount: displayed.length,
      itemBuilder: (context, index) {
        final keyword = displayed[index];
        return InkWell(
          onTap: () => onTapKeyword(keyword),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    keyword,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
