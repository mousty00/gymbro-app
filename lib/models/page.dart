import 'json.dart';

/// `Connection<D>` del backend: `{results, pageInfo, totalCount}`.
class PageResult<T> {
  const PageResult({
    required this.results,
    required this.hasNext,
    required this.currentPage,
    required this.totalCount,
  });

  final List<T> results;
  final bool hasNext;
  final int currentPage;
  final int totalCount;

  factory PageResult.fromJson(Json json, T Function(Json) fromJson) {
    final info = (json['pageInfo'] as Map?) ?? const {};
    return PageResult(
      results: parseList(json['results'], fromJson),
      hasNext: info['hasNext'] == true,
      currentPage: parseInt(info['currentPage']),
      totalCount: parseInt(json['totalCount']),
    );
  }
}
