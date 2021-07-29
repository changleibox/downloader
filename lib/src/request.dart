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
