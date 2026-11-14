import 'dart:convert';
import 'dart:io';

class ApiPage {
  const ApiPage(this.statusCode, this.body, this.pages);

  final int statusCode;
  final String body;
  final int pages;

  bool hasNextPage(int page) => page < pages;
}

Future<ApiPage> fetchApiPage(Uri uri) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final HttpClientRequest request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 15),
    );
    final String body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    final int total =
        int.tryParse(response.headers.value('X-WP-Total') ?? '') ?? 0;
    final int pageSize =
        int.tryParse(uri.queryParameters['per_page'] ?? '') ?? 10;
    final int pages =
        int.tryParse(response.headers.value('X-WP-TotalPages') ?? '') ??
        (pageSize > 0 ? (total / pageSize).ceil() : 0);
    return ApiPage(response.statusCode, body, pages);
  } finally {
    client.close(force: true);
  }
}
