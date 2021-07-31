/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'entry_stub.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'entry/downloader_dio_for_browser.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'entry/downloader_dio_for_native.dart';

const _capacity = 10;

/// 返回[FutureOr]的[ValueChanged]
typedef FutureOrValueChanged<R, T> = FutureOr<R> Function(T value);

/// Created by changlei on 2021/7/30.
///
/// 下载管理器专用[Dio]
abstract class DownloaderDio with DioMixin implements Dio {
  /// 构造函数
  factory DownloaderDio([BaseOptions? options]) => createDio(options);

  /// 获取stream
  Future<void> asStream(
    final String path, {
    final ProgressCallback? onReceiveProgress,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final ValueChanged<Uint8List>? onData,
    final VoidCallback? onDone,
    final Function? onError,
    final bool? cancelOnError,
    final CancelToken? cancelToken,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  });

  /// 获取bytes
  Future<Uint8List?> asBytes(
    final String path, {
    final ProgressCallback? onReceiveProgress,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final ValueChanged<Uint8List>? onData,
    final CancelToken? cancelToken,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  });

  /// 获取文件长度
  Future<int> contentLength(
    final String path, {
    final CancelToken? cancelToken,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  });

  /// 批量获取[paths]对应的文件大小总合
  Future<int> contentLengths(
    final Iterable<String> paths, {
    final CancelToken? cancelToken,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  });
}

/// 扩展dio
/// 为了防止一次性请求太多，我们限制最多只能进行[_capacity]个请求
mixin DownloaderDioMixin on DioMixin implements DownloaderDio {
  // 正在等待的队列
  final _waitingQueue = ListQueue<Function>(_capacity);

  // 正在进行的队列
  final _ongoingQueue = ListQueue<Function>(_capacity);

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) {
    final completer = Completer<Response<T>>();
    void next() {
      _ongoingQueue.removeFirst();
      if (_waitingQueue.isNotEmpty) {
        _ongoingQueue.add(_waitingQueue.removeFirst()..call());
      }
    }

    void execute() {
      final then = completer.complete;
      final Function onError = completer.completeError;
      super.fetch<T>(requestOptions).then(then).catchError(onError).whenComplete(next);
    }

    // 当正在进行的请求达到上限，则把新进来的请求放在等待队列中，等待进行中队列请求完成
    if (_ongoingQueue.length < _capacity && _waitingQueue.isEmpty) {
      _ongoingQueue.add(execute..call());
    } else {
      _waitingQueue.add(execute);
    }
    return completer.future;
  }

  @override
  Future<void> asStream(
    final String path, {
    final ProgressCallback? onReceiveProgress,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final ValueChanged<Uint8List>? onData,
    final VoidCallback? onDone,
    final Function? onError,
    final bool? cancelOnError,
    final CancelToken? cancelToken,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  }) async {
    final mergedOptions = options ?? Options();
    mergedOptions.responseType = ResponseType.stream;
    final response = await request<ResponseBody>(
      path,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
      options: mergedOptions,
      data: data,
    );
    final responseBody = response.data;
    if (responseBody == null) {
      return null;
    }
    final headers = await _parseHeaders(response, onHeaders);
    final total = _parseLength(headers, lengthHeader);
    final completer = Completer<void>();
    var received = 0;
    responseBody.stream.listen(
      (event) {
        received += event.length;
        onReceiveProgress?.call(received, total);
        onData?.call(event);
      },
      onDone: () {
        completer.complete();
        onDone?.call();
      },
      onError: (Object error, [StackTrace? stackTrace]) {
        completer.completeError(error, stackTrace);
        onError?.call(error, stackTrace);
      },
      cancelOnError: cancelOnError,
    );
    return completer.future;
  }

  @override
  Future<Uint8List?> asBytes(
    final String path, {
    final ProgressCallback? onReceiveProgress,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final ValueChanged<Uint8List>? onData,
    final CancelToken? cancelToken,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  }) {
    final completer = Completer<Uint8List>();
    final data = <int>[];
    asStream(
      path,
      onReceiveProgress: onReceiveProgress,
      onHeaders: onHeaders,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
      lengthHeader: lengthHeader,
      options: options,
      data: data,
      onData: (value) {
        data.addAll(value);
        onData?.call(value);
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

  @override
  Future<int> contentLength(
    final String path, {
    final CancelToken? cancelToken,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  }) async {
    final response = await head<void>(
      path,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
      options: options,
      data: data,
    );
    final headers = await _parseHeaders(response, onHeaders);
    return _parseLength(headers, lengthHeader);
  }

  @override
  Future<int> contentLengths(
    final Iterable<String> paths, {
    final CancelToken? cancelToken,
    final ValueChanged<Headers>? onHeaders,
    final Map<String, dynamic>? queryParameters,
    final String lengthHeader = Headers.contentLengthHeader,
    final dynamic data,
    final Options? options,
  }) async {
    if (paths.isEmpty) {
      return 0;
    }
    final lengths = await Future.wait(paths.map((e) {
      return contentLength(
        e,
        cancelToken: cancelToken,
        onHeaders: onHeaders,
        queryParameters: queryParameters,
        lengthHeader: lengthHeader,
        options: options,
        data: data,
      );
    }));
    return lengths.reduce((value, element) => value + element);
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

  Future<Headers> _parseHeaders(final Response response, FutureOrValueChanged<void, Headers>? onHeaders) async {
    final headers = response.headers;
    if (onHeaders != null) {
      // Add real uri and redirect information to headers
      headers.add('redirects', response.redirects.length.toString());
      headers.add('uri', response.realUri.toString());
      final futureOr = onHeaders(headers);
      if (futureOr is Future) {
        await futureOr;
      }
    }
    return headers;
  }
}
