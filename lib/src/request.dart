import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Created by changlei on 2021/7/28.
///
/// 网络请求
const _timeout = Duration(hours: 24);

final _plainRequest = Dio(
  BaseOptions(
    connectTimeout: _timeout.inMilliseconds,
    sendTimeout: _timeout.inMilliseconds,
    receiveTimeout: _timeout.inMilliseconds,
    followRedirects: true,
    maxRedirects: 10,
    receiveDataWhenStatusError: true,
  ),
);
final _logInterceptor = LogInterceptor(
  request: true,
  requestHeader: true,
  requestBody: true,
  responseHeader: true,
  responseBody: true,
  error: true,
);

/// 下载文件
Future<Uint8List?> downloadToBytes(String uri, {CancelToken? cancelToken}) async {
  final interceptors = _plainRequest.interceptors;
  if (!interceptors.contains(_logInterceptor)) {
    interceptors.add(_logInterceptor);
  }
  final response = await _plainRequest.request<ResponseBody>(
    uri,
    options: Options(
      responseType: ResponseType.stream,
    ),
    cancelToken: cancelToken,
  );
  final responseBody = response.data;
  if (responseBody == null) {
    return null;
  }
  final data = <int>[];
  await responseBody.stream.forEach(data.addAll);
  return Uint8List.fromList(data);
}

/// 批量获取[uris]对应的文件大小总合
Future<int> requestLength(
  Iterable<String> uris, {
  String lengthHeader = Headers.contentLengthHeader,
  CancelToken? cancelToken,
}) async {
  final interceptors = _plainRequest.interceptors;
  if (!interceptors.contains(_logInterceptor)) {
    interceptors.add(_logInterceptor);
  }
  if (uris.isEmpty) {
    return -1;
  }
  try {
    final futures = uris.map((e) async {
      final head = await _plainRequest.head<void>(e);
      final headers = head.headers;
      var compressed = false;
      final contentEncoding = headers.value(Headers.contentEncodingHeader);
      if (contentEncoding != null) {
        compressed = ['gzip', 'deflate', 'compress'].contains(contentEncoding);
      }
      var total = 0;
      if (lengthHeader == Headers.contentLengthHeader && compressed) {
        total = -1;
      } else {
        total = int.parse(headers.value(lengthHeader) ?? '-1');
      }
      return total;
    });
    return (await Future.wait(futures)).reduce((value, element) => value + element);
  } catch (e) {
    return -1;
  }
}
