import 'package:http/http.dart' as http;

/// Native HTTP clients have no browser cookie jar.
http.Client createRoastHttpClient() => http.Client();
