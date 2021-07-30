/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/downloader.dart';
import 'package:downloader/src/universal_downloader.dart';
import 'package:flutter/cupertino.dart';

/// 构建Downloader
typedef DownloaderBuilder = Downloader Function(
  String url,
  ProgressCallback? onReceiveProgress,
);

/// Created by changlei on 2021/7/29.
///
/// 下载器
abstract class Downloader {
  /// 构造函数
  @protected
  Downloader({
    required this.url,
    this.onReceiveProgress,
  })  : _cancelToken = CancelToken(),
        _controller = StreamController<Uint8List>.broadcast() {
    _controller.onCancel = () => _cancelToken.cancel();
  }

  /// 构造函数，按照文件类型选择合适的下载器
  factory Downloader.extension({
    required String url,
    ProgressCallback? onReceiveProgress,
  }) {
    final pointIndex = url.lastIndexOf('.');
    var extension = '';
    if (pointIndex >= 0 || pointIndex < url.length) {
      extension = url.substring(pointIndex);
    }
    final keys = _downloaderBuilders.keys;
    for (var key in keys) {
      final regExp = RegExp(key, caseSensitive: false);
      if (regExp.hasMatch(extension)) {
        return _downloaderBuilders[key]!(url, onReceiveProgress);
      }
    }
    return UniversalDownloader(
      url: url,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 使用[Stream]下载
  static Stream<Uint8List> asStream(
    String url, {
    ProgressCallback? onReceiveProgress,
  }) {
    final downloader = Downloader.extension(
      url: url,
      onReceiveProgress: onReceiveProgress,
    );
    downloader.download(url);
    return downloader.stream;
  }

  /// 使用[Uint8List]下载
  static Future<Uint8List> asBytes(
    String url, {
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    final bytes = <int>[];
    final completer = Completer<Uint8List>();
    final subscription = asStream(
      url,
      onReceiveProgress: onReceiveProgress,
    ).listen(
      bytes.addAll,
      onDone: () {
        completer.complete(Uint8List.fromList(bytes));
      },
      onError: (Object error, [StackTrace? stackTrace]) {
        completer.completeError(error, stackTrace);
      },
      cancelOnError: true,
    );
    cancelToken?.whenCancel.then((value) {
      subscription.cancel();
    });
    return completer.future;
  }

  /// 使用[File]下载
  static Future<void> asFile(
    String url,
    String path, {
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    final completer = Completer<void>();
    final target = File(path);
    if (target.existsSync()) {
      target.deleteSync(recursive: true);
    }
    target.createSync(recursive: true);
    final ioSink = target.openWrite();
    Future<void> onDone() async {
      try {
        await ioSink.flush();
        await ioSink.close();
        completer.complete();
      } catch (error, stackTrace) {
        target.deleteSync(recursive: true);
        completer.completeError(error, stackTrace);
      }
    }

    Future<void> onError(Object error, [StackTrace? stackTrace]) async {
      try {
        await ioSink.flush();
        await ioSink.close();
      } finally {
        target.deleteSync(recursive: true);
        completer.completeError(error, stackTrace);
      }
    }

    final subscription = asStream(
      url,
      onReceiveProgress: onReceiveProgress,
    ).listen(
      ioSink.add,
      onDone: onDone,
      onError: onError,
      cancelOnError: true,
    );
    cancelToken?.whenCancel.then((value) {
      subscription.cancel();
    });
    return completer.future;
  }

  /// 加载下载管理器，按照后缀名
  /// 注意，如果传入的[extensions]已经存在，则会替换原来的[downloader]
  /// 传入空的[extensions]，则代表匹配所有的文件类型
  static void put(List<String> extensions, DownloaderBuilder builder) {
    final sortedExtensions = List.of(extensions)..sort();
    var key = sortedExtensions.join('|');
    if (sortedExtensions.isEmpty) {
      key = '.*?';
    }
    _downloaderBuilders['\.$key\$'] = builder;
  }

  static final _downloaderBuilders = <String, DownloaderBuilder>{
    'm3u8': (url, onReceiveProgress) {
      return M3u8Downloader(
        url: url,
        onReceiveProgress: onReceiveProgress,
      );
    },
  };

  /// url
  final String url;

  /// 监听进度
  final ProgressCallback? onReceiveProgress;

  final CancelToken _cancelToken;

  final StreamController<Uint8List> _controller;

  /// stream
  Stream<Uint8List> get stream => _controller.stream;

  /// cancelToken
  @protected
  CancelToken get cancelToken => _cancelToken;

  /// 是否已取消
  bool get isCancelled => _cancelToken.isCancelled || _controller.isClosed;

  /// 取消下载
  Future<void> cancel() async {
    if (_controller.isClosed) {
      return;
    }
    await _controller.close();
  }

  /// download
  Future<void> download(String url) async {
    if (_controller.isClosed) {
      throw StateError('该下载器已取消');
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
    if (_controller.isClosed || (error is DioError && error.type == DioErrorType.cancel)) {
      return;
    }
    _controller.addError(error, stackTrace);
  }

  void _onComplete() {
    if (_controller.isClosed) {
      return;
    }
    _controller.close();
  }
}
