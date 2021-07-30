/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/src/dio/downloader_dio.dart';
import 'package:flutter/cupertino.dart';

const _timeout = Duration(hours: 24);

/// Created by changlei on 2021/7/28.
///
/// 网络请求
final _plainRequest = DownloaderDio(
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
  final String uri, {
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
  final Iterable<String> uris, {
  final String lengthHeader = Headers.contentLengthHeader,
  final CancelToken? cancelToken,
}) async {
  if (uris.isEmpty) {
    return 0;
  }
  final lengths = await Future.wait(uris.map((e) {
    return _requestLength(e, cancelToken);
  }));
  return lengths.reduce((value, element) => value + element);
}

Future<int> _requestLength(
  final String uri, [
  final CancelToken? cancelToken,
]) async {
  final response = await _plainRequest.head<void>(
    uri,
    cancelToken: cancelToken,
  );
  return _parseLength(response.headers);
}

int _parseLength(
  final Headers headers, [
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
