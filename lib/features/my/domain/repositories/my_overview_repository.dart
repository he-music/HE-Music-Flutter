import '../entities/my_overview.dart';

abstract interface class MyOverviewRepository {
  Future<MyOverview> fetchOverview();
}
