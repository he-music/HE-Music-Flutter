import 'home_page_section.dart';

class HomePageResult {
  const HomePageResult({required this.sections, required this.hasMore});

  final List<HomePageSection> sections;
  final bool hasMore;
}
