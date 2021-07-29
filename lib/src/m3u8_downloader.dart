/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/src/m3u8.dart';
import 'package:downloader/src/request.dart';

/// Created by changlei on 2021/7/27.
///
/// .m3u8下载器
class M3u8Downloader {
  /// 构造函数
  M3u8Downloader({
    required this.url,
    this.progress,
  })  : _cancelToken = CancelToken(),
        _controller = StreamController<Uint8List>.broadcast()..onCancel {
    _controller.onCancel = () {
      _cancelToken.cancel();
    };
  }

  /// url
  final String url;

  /// 监听进度
  final ProgressCallback? progress;

  final CancelToken _cancelToken;

  final StreamController<Uint8List> _controller;

  /// 使用[Stream]下载
  static Stream<Uint8List> asStream(
    String url, {
    ProgressCallback? progress,
  }) {
    final downloader = M3u8Downloader(
      url: url,
      progress: progress,
    );
    downloader.download(url);
    return downloader.stream;
  }

  /// 使用[Uint8List]下载
  static Future<Uint8List> asBytes(
    String url, {
    ProgressCallback? progress,
  }) async {
    final bytes = <int>[];
    final stream = asStream(
      url,
      progress: progress,
    );
    await stream.forEach(bytes.addAll);
    return Uint8List.fromList(bytes);
  }

  /// 使用[File]下载
  static Future<void> asFile(
    String url,
    String path, {
    ProgressCallback? progress,
  }) {
    final completer = Completer<void>();
    final target = File(path);
    if (target.existsSync()) {
      target.deleteSync(recursive: true);
    }
    target.createSync(recursive: true);
    final accessFile = target.openSync(
      mode: FileMode.write,
    );
    asStream(
      url,
      progress: progress,
    ).listen(
      accessFile.writeFrom,
      onDone: completer.complete,
      onError: (Object error, [StackTrace? stackTrace]) {
        target.deleteSync(recursive: true);
        completer.completeError(error, stackTrace);
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// stream
  Stream<Uint8List> get stream => _controller.stream;

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
      await _download(url);
    } catch (error, stackTrack) {
      _onError(error, stackTrack);
    } finally {
      _onComplete();
    }
  }

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

  Future<void> _download(String url) async {
    var m3u8 = await M3u8.read(url);
    final streamInf = m3u8?.streamInf;
    if (streamInf?.isNotEmpty == true) {
      m3u8 = await M3u8.read(streamInf!.first.uri);
    }
    if (m3u8 == null) {
      return null;
    }

    final key = m3u8.key;
    final keyData = await key?.keyData;

    // 下载ts文件列表
    final playlist = [...?m3u8.playlist];
    for (var value in playlist) {
      if (_cancelToken.isCancelled) {
        break;
      }
      final data = await downloadToBytes(
        value.uri,
        cancelToken: _cancelToken,
      );
      if (_controller.isClosed) {
        break;
      }
      if (data == null) {
        continue;
      }
      _onData(decrypt(data, keyData, key?.iv));
    }
  }
}
