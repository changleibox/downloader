/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/downloader.dart';
import 'package:downloader/src/dio/downloader_dio.dart';
import 'package:downloader/src/universal/universal_downloader.dart';
import 'package:flutter/cupertino.dart';

/// 构建Downloader
typedef DownloaderBuilder = Downloader Function(
  String url,
  DownloadOptions? options,
);

const _allMatchRegExp = r'.*?';

/// Created by changlei on 2021/7/29.
///
/// 下载器
abstract class Downloader {
  /// 构造函数
  @protected
  Downloader({
    required this.url,
    this.options,
  })  : _cancelToken = CancelToken(),
        _controller = StreamController<Uint8List>() {
    _controller.onCancel = () {
      if (!isCancelled) {
        _cancelToken.cancel();
      }
    };
    _cancelToken.whenCancel.then((value) {
      return _controller.onCancel = null;
    });
  }

  /// 构造函数，按照文件类型选择合适的下载器
  factory Downloader.extension({
    required String url,
    DownloadOptions? options,
  }) {
    final pointIndex = url.lastIndexOf('.');
    var extension = _allMatchRegExp;
    if (pointIndex >= 0 || pointIndex < url.length) {
      extension = url.substring(pointIndex);
    }
    final keys = _downloaderBuilders.keys;
    for (var key in keys) {
      final regExp = RegExp('\.$key\$', caseSensitive: false);
      if (regExp.hasMatch(extension)) {
        return _downloaderBuilders[key]!(url, options);
      }
    }
    return UniversalDownloader(
      url: url,
      options: options,
    );
  }

  /// 使用[Stream]下载
  static Stream<Uint8List> asStream(
    String url, {
    BarePoledDownloadOptions? options,
    ProgressCallback? onReceiveProgress,
    FutureOrValueChanged<void, Headers>? onHeaders,
  }) {
    final downloader = Downloader.extension(
      url: url,
      options: (options ?? const DownloadOptions()).copyWith(
        onReceiveProgress: onReceiveProgress,
        onHeaders: onHeaders,
      ),
    );
    downloader.download(url);
    return downloader.stream;
  }

  /// 使用[StreamSubscription]下载
  static StreamSubscription<Uint8List> asSubscribe(
    String url, {
    CancelToken? cancelToken,
    BarePoledDownloadOptions? options,
    ProgressCallback? onReceiveProgress,
    FutureOrValueChanged<void, Headers>? onHeaders,
    ValueChanged<Uint8List>? onData,
    Future<void> Function(Object error, [StackTrace? stackTrace])? onError,
    Future<void> Function()? onDone,
    bool? cancelOnError = true,
  }) {
    final subscription = asStream(
      url,
      options: options,
      onReceiveProgress: onReceiveProgress,
      onHeaders: onHeaders,
    ).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
    cancelToken?.whenCancel.then((value) async {
      try {
        await subscription.cancel();
      } finally {
        await onError?.call(value, value.stackTrace);
      }
    });
    return subscription;
  }

  /// 使用[Uint8List]下载
  static Future<Uint8List> asBytes(
    String url, {
    CancelToken? cancelToken,
    BarePoledDownloadOptions? options,
    ProgressCallback? onReceiveProgress,
    FutureOrValueChanged<void, Headers>? onHeaders,
  }) {
    final bytes = <int>[];
    final completer = Completer<Uint8List>();
    Future<void> onDone() async {
      final data = Uint8List.fromList(bytes);
      bytes.clear();
      completer.complete(data);
    }

    Future<void> onError(Object error, [StackTrace? stackTrace]) async {
      bytes.clear();
      completer.completeError(error, stackTrace);
    }

    asSubscribe(
      url,
      cancelToken: cancelToken,
      options: options,
      onReceiveProgress: onReceiveProgress,
      onHeaders: onHeaders,
      onData: bytes.addAll,
      onDone: onDone,
      onError: onError,
    );
    return completer.future;
  }

  /// 使用[File]下载
  static Future<void> asFile(
    String url,
    dynamic savePath, {
    CancelToken? cancelToken,
    BarePoledDownloadOptions? options,
    ProgressCallback? onReceiveProgress,
    FutureOrValueChanged<void, Headers>? onHeaders,
    bool deleteOnError = true,
  }) {
    File? target;
    void deleteTarget() {
      if (deleteOnError && target?.existsSync() == true) {
        target!.deleteSync(recursive: true);
      }
      target = null;
    }

    IOSink? ioSink;
    Future<void> closeIOSink() async {
      try {
        await ioSink?.flush();
        await ioSink?.close();
      } finally {
        ioSink = null;
      }
    }

    var closed = false;
    Future<void> closeAndDelete() async {
      if (closed) {
        return;
      }
      closed = true;
      try {
        await closeIOSink();
      } finally {
        deleteTarget();
      }
    }

    Future<void> createTarget(Headers headers) async {
      if (headers.isContentLength || !headers.isDownload) {
        return;
      }
      String newPath;
      if (savePath is String) {
        newPath = savePath;
      } else if (savePath is FutureOrValueChanged<String, Headers>) {
        newPath = await savePath(headers);
      } else {
        throw ArgumentError.value(
          savePath,
          'savePath',
          'callback type must be `FutureOr<String> Function(Headers)` or `String`',
        );
      }
      if (newPath == target?.path) {
        return;
      }
      if (target?.existsSync() == true) {
        target = target!.renameSync(newPath);
      } else {
        target = File(newPath)..createSync(recursive: true);
      }
      ioSink ??= target!.openWrite(mode: FileMode.writeOnly);
    }

    Future<void> handleHeaders(Headers headers) async {
      try {
        await createTarget(headers);
      } finally {
        await onHeaders?.call(headers);
      }
    }

    final completer = Completer<void>();
    Future<void> onDone() async {
      try {
        await closeIOSink();
        completer.complete();
      } catch (error, stackTrace) {
        deleteTarget();
        completer.completeError(error, stackTrace);
      }
    }

    Future<void> onError(Object error, [StackTrace? stackTrace]) async {
      try {
        await closeAndDelete();
      } finally {
        completer.completeError(error, stackTrace);
      }
    }

    asSubscribe(
      url,
      cancelToken: cancelToken,
      options: options,
      onReceiveProgress: onReceiveProgress,
      onHeaders: handleHeaders,
      onData: (event) => ioSink?.add(event),
      onDone: onDone,
      onError: onError,
    );
    return completer.future;
  }

  /// 可以给下载管理器设置过滤器
  static Interceptors get interceptors => downloadInterceptors;

  /// 加载下载管理器，按照后缀名
  /// 注意，如果传入的[extensions]已经存在，则会替换原来的[downloader]
  /// 传入空的[extensions]，则代表匹配所有的文件类型
  static void put(List<String> extensions, DownloaderBuilder builder) {
    final sortedExtensions = List.of(extensions)..sort();
    var key = sortedExtensions.join('|');
    if (sortedExtensions.isEmpty) {
      key = _allMatchRegExp;
    }
    _downloaderBuilders[key] = builder;
  }

  static final _downloaderBuilders = <String, DownloaderBuilder>{
    'm3u8': (url, options) {
      return M3u8Downloader(
        url: url,
        options: options,
      );
    },
  };

  /// url
  final String url;

  /// 下载配置
  final DownloadOptions? options;

  final CancelToken _cancelToken;

  final StreamController<Uint8List> _controller;

  /// stream
  Stream<Uint8List> get stream {
    if (isCancelled) {
      throw StateError('下载器已取消');
    }
    return _controller.stream;
  }

  /// cancelToken
  @protected
  CancelToken get cancelToken => _cancelToken;

  /// 是否已取消
  bool get isCancelled => _cancelToken.isCancelled || _controller.isClosed;

  /// 取消下载
  Future<void> cancel() async {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  /// download
  Future<void> download(String url) async {
    if (isCancelled) {
      throw StateError('下载器已取消');
    }
    try {
      await onDownload(url, _onData);
    } catch (error, stackTrack) {
      _onError(error, stackTrack);
    } finally {
      _onComplete();
    }
  }

  /// 下载
  @protected
  Future<void> onDownload(String url, ValueChanged<Uint8List> onData);

  void _onData(Uint8List value) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(value);
  }

  void _onError(Object error, [StackTrace? stackTrace]) {
    if (_controller.isClosed) {
      return;
    }
    _controller.addError(error, stackTrace);
  }

  void _onComplete() {
    cancel();
  }
}
