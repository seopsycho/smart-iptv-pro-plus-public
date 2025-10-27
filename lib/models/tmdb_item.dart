class TmdbItem {
  final int id;
  final String title;
  final String overview;
  final String? posterUrl;
  final bool isSeries;
  TmdbItem({
    required this.id,
    required this.title,
    required this.overview,
    this.posterUrl,
    required this.isSeries,
  });
}
