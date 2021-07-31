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
    final ValueChanged<Uint8List>? onData,
    final VoidCallback? onDone,
    final Function? onError,
    final bool? cancelOnError,
    final CancelToken? cancelToken,
    final DownloadOptions? options,
  });

  /// 获取bytes
  Future<Uint8List?> asBytes(
    final String path, {
    final ValueChanged<Uint8List>? onData,
    final CancelToken? cancelToken,
    final DownloadOptions? options,
  });

  /// 获取文件长度
  Future<int> contentLength(
    final String path, {
    final CancelToken? cancelToken,
    final DownloadOptions? options,
  });

  /// 批量获取[paths]对应的文件大小总合
  Future<int> contentLengths(
    final Iterable<String> paths, {
    final CancelToken? cancelToken,
    final DownloadOptions? options,
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
    final ValueChanged<Uint8List>? onData,
    final VoidCallback? onDone,
    final Function? onError,
    final bool? cancelOnError,
    final CancelToken? cancelToken,
    final DownloadOptions? options,
  }) async {
    final mergedOptions = options?.options ?? Options();
    mergedOptions.responseType = ResponseType.stream;
    final response = await request<ResponseBody>(
      path,
      cancelToken: cancelToken,
      queryParameters: options?.queryParameters,
      options: mergedOptions,
      data: options?.data,
    );
    final responseBody = response.data;
    if (responseBody == null) {
      return null;
    }
    final headers = await _parseHeaders(response, options?.onHeaders);
    final total = _parseLength(headers, options?.lengthHeader);
    final completer = Completer<void>();
    var received = 0;
    responseBody.stream.listen(
      (event) {
        received += event.length;
        options?.onReceiveProgress?.call(received, total);
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
    final ValueChanged<Uint8List>? onData,
    final CancelToken? cancelToken,
    final DownloadOptions? options,
  }) {
    final completer = Completer<Uint8List>();
    final data = <int>[];
    asStream(
      path,
      cancelToken: cancelToken,
      options: options,
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
    final DownloadOptions? options,
  }) async {
    final response = await head<void>(
      path,
      cancelToken: cancelToken,
      queryParameters: options?.queryParameters,
      options: options?.options,
      data: options?.data,
    );
    final headers = await _parseHeaders(
      response,
      options?.onHeaders,
      Headers.contentLengthHeader,
    );
    return _parseLength(headers, options?.lengthHeader);
  }

  @override
  Future<int> contentLengths(
    final Iterable<String> paths, {
    final CancelToken? cancelToken,
    final DownloadOptions? options,
  }) async {
    if (paths.isEmpty) {
      return 0;
    }
    final lengths = await Future.wait(paths.map((e) {
      return contentLength(
        e,
        cancelToken: cancelToken,
        options: options,
      );
    }));
    return lengths.reduce((value, element) => value + element);
  }

  int _parseLength(
    final Headers headers, [
    String? lengthHeader,
  ]) {
    lengthHeader ??= Headers.contentLengthHeader;
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

  Future<Headers> _parseHeaders(
    final Response response,
    FutureOrValueChanged<void, Headers>? onHeaders, [
    String? behavior,
  ]) async {
    final headers = response.headers;
    if (onHeaders != null) {
      // Add real uri and redirect information to headers
      headers.add('redirects', response.redirects.length.toString());
      headers.add('uri', response.realUri.toString());
      if (behavior != null) {
        headers.add('behavior', behavior);
      }
      final futureOr = onHeaders(headers);
      if (futureOr is Future) {
        await futureOr;
      }
    }
    return headers;
  }
}

/// 扩展[Headers]
extension HeadersBehavior on Headers {
  /// 是否正在请求contentLength
  bool get isContentLength => value('behavior') == Headers.contentLengthHeader;
}

/// 配置
class DownloadOptions {
  /// 构造函数
  const DownloadOptions({
    this.onReceiveProgress,
    this.onHeaders,
    this.queryParameters,
    this.lengthHeader = Headers.contentLengthHeader,
    this.data,
    this.options,
  });

  /// 监听进度
  final ProgressCallback? onReceiveProgress;

  /// 在返回headers的时候回调
  final FutureOrValueChanged<void, Headers>? onHeaders;

  /// 请求参数
  final Map<String, dynamic>? queryParameters;

  /// contentLength的key
  final String lengthHeader;

  /// 请求实体
  final Object? data;

  /// [Options]
  final Options? options;

  /// 复制
  DownloadOptions copyWith({
    final ProgressCallback? onReceiveProgress,
    final FutureOrValueChanged<void, Headers>? onHeaders,
    final Map<String, dynamic>? queryParameters,
    final String? lengthHeader,
    final Object? data,
    final Options? options,
  }) {
    return DownloadOptions(
      onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
      onHeaders: onHeaders ?? this.onHeaders,
      queryParameters: queryParameters ?? this.queryParameters,
      lengthHeader: lengthHeader ?? this.lengthHeader,
      data: data ?? this.data,
      options: options ?? this.options,
    );
  }

  /// 只有请求参数的[DownloadOptions]
  DownloadOptions get barePole {
    return DownloadOptions(
      queryParameters: queryParameters,
      lengthHeader: lengthHeader,
      data: data,
      options: options,
    );
  }
}
