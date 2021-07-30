/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

const int _initialCapacity = 10;

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

/// 可以给下载管理器设置过滤器
Interceptors get interceptors => _plainRequest.interceptors;

/// 下载文件
Future<Uint8List?> requestAsBytes(
  String uri, {
  final ProgressCallback? onReceiveProgress,
  final ValueChanged<Uint8List>? onReceive,
  final CancelToken? cancelToken,
}) async {
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
  final String lengthHeader = Headers.contentLengthHeader,
  final CancelToken? cancelToken,
}) async {
  if (uris.isEmpty) {
    return 0;
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

List<List<String>> _collapseUris(
  Iterable<String> uris, [
  final int maxLength = _initialCapacity,
]) {
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

int _parseLength(
  Headers headers, [
  final String lengthHeader = Headers.contentLengthHeader,
]) {
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
