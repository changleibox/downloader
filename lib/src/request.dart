import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

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
Future<Uint8List?> requestAsBytes(
  String uri, {
  ProgressCallback? onReceiveProgress,
  ValueChanged<Uint8List>? onReceive,
  CancelToken? cancelToken,
}) async {
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
  final total = _parseLength(response.headers);
  var received = 0;
  final completer = Completer<Uint8List>();
  final data = <int>[];
  responseBody.stream.listen(
    (event) {
      data.addAll(event);
      received += event.length;
      onReceiveProgress?.call(received, total);
      onReceive?.call(event);
    },
    onDone: () {
      completer.complete(Uint8List.fromList(data));
    },
    onError: (Object error, [StackTrace? stackTrace]) {
      completer.completeError(error, stackTrace);
    },
    cancelOnError: true,
  );
  return completer.future;
}

/// 批量获取[uris]对应的文件大小总合
Future<int> requestLength(
  Iterable<String> uris, {
  String lengthHeader = Headers.contentLengthHeader,
  CancelToken? cancelToken,
}) async {
  if (uris.isEmpty) {
    return 0;
  }
  final interceptors = _plainRequest.interceptors;
  if (!interceptors.contains(_logInterceptor)) {
    interceptors.add(_logInterceptor);
  }
  Future<int> getLength(List<String> uris) async {
    try {
      final lengths = await Future.wait(uris.map((e) {
        return _requestLength(e, cancelToken);
      }));
      return lengths.reduce((value, element) => value + element);
    } catch (e) {
      return 0;
    }
  }

  var length = 0;
  for (var uris in _collapseUris(uris)) {
    length += await getLength(uris);
  }
  return length;
}

List<List<String>> _collapseUris(Iterable<String> uris, [int maxLength = 10]) {
  final length = uris.length;
  if (length <= maxLength) {
    return [uris.toList()];
  }
  final collapsedUris = <List<String>>[];
  for (var i = 0; i < (length ~/ maxLength + (length % maxLength > 0 ? 1 : 0)); i++) {
    collapsedUris.add(List.of(uris).sublist(i * maxLength, min(length, (i + 1) * maxLength)));
  }
  return collapsedUris;
}

Future<int> _requestLength(String uri, [CancelToken? cancelToken]) async {
  final response = await _plainRequest.head<void>(
    uri,
    cancelToken: cancelToken,
  );
  return _parseLength(response.headers);
}

int _parseLength(Headers headers, [String lengthHeader = Headers.contentLengthHeader]) {
  var compressed = false;
  final contentEncoding = headers.value(Headers.contentEncodingHeader);
  if (contentEncoding != null) {
    compressed = ['gzip', 'deflate', 'compress'].contains(contentEncoding);
  }
  var total = 0;
  if (lengthHeader == Headers.contentLengthHeader && compressed) {
    total = 0;
  } else {
    total = int.parse(headers.value(lengthHeader) ?? '0');
  }
  return total;
}
