class AppRoutes {
  static const splash = '/splash';
  static const forecast = '/forecast';
  // Retired URLs retained only for safe upgrade redirects.
  static const roasts = '/roasts';
  static const roastReveal = '/roasts/reveal';
  static const radar = '/radar';
  static const fun = '/fun';
  static const memeGenerator = '/fun/meme';
  static const settings = '/settings';
  static const planCast = '/plancast';
  static const about = '/settings/about';

  // Compatibility aliases for older app code and bookmarks.
  static const home = forecast;
  static const burns = roasts;

  static String? retiredRedirect(Uri uri) {
    final first = uri.path.split('/').where((s) => s.isNotEmpty).firstOrNull;
    return const {'roasts', 'roast', 'burns', 'personas', 'persona', 'closet'}
            .contains(first)
        ? forecast
        : null;
  }
}
