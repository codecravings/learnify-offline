/// Aggregated search results from multiple collections.
class SearchResults {
  final List<Map<String, dynamic>> challenges;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> users;
  final String query;

  const SearchResults({
    required this.challenges,
    required this.posts,
    required this.users,
    required this.query,
  });

  /// Total number of results across all categories.
  int get totalCount => challenges.length + posts.length + users.length;

  /// Whether the search returned any results.
  bool get isEmpty => totalCount == 0;

  bool get isNotEmpty => !isEmpty;
}
