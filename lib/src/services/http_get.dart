import 'package:http/http.dart' as http;

import '../constants.dart';

class HttpText {
  const HttpText({required this.status, required this.body});

  final int status;
  final String body;

  bool get ok => status >= 200 && status < 300;
}

abstract class HttpGet {
  Future<HttpText> get(Uri uri, {Map<String, String>? headers});
}

class IoHttpGet implements HttpGet {
  IoHttpGet([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<HttpText> get(Uri uri, {Map<String, String>? headers}) async {
    final response = await _client
        .get(uri, headers: {'User-Agent': kUserAgent, ...?headers})
        .timeout(const Duration(seconds: 25));
    return HttpText(status: response.statusCode, body: response.body);
  }
}

class ByteFetch {
  const ByteFetch({required this.status, required this.bytes, this.length});

  final int status;
  final int? length;
  final Stream<List<int>> bytes;
}

abstract class ByteSource {
  Future<ByteFetch> open(Uri uri);
}

class IoByteSource implements ByteSource {
  IoByteSource([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<ByteFetch> open(Uri uri) async {
    final request = http.Request('GET', uri);
    request.headers['User-Agent'] = kUserAgent;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    return ByteFetch(
      status: response.statusCode,
      length: response.contentLength,
      bytes: response.stream,
    );
  }

  void close() => _client.close();
}
