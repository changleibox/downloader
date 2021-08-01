/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:downloader/src/dio/downloader_dio.dart';
import 'package:downloader/src/downloader.dart';
import 'package:downloader/src/m3u8/m3u8.dart';
import 'package:flutter/foundation.dart';

/// Created by changlei on 2021/7/27.
///
/// .m3u8下载器
class M3u8Downloader extends Downloader {
  /// 构造函数
  M3u8Downloader({
    required String url,
    DownloadOptions? options,
  }) : super(url: url, options: options);

  @override
  Future<void> onDownload(String url, ValueChanged<Uint8List> onData) async {
    final barePoleOptions = options?.barePoled;
    var m3u8 = await M3u8.parse(
      url,
      cancelToken: cancelToken,
      options: barePoleOptions,
    );
    final streamInf = m3u8?.streamInf;
    if (streamInf?.isNotEmpty == true) {
      m3u8 = await M3u8.parse(
        streamInf!.first.uri,
        cancelToken: cancelToken,
        options: barePoleOptions,
      );
    }
    if (m3u8 == null) {
      return null;
    }

    final extKey = m3u8.key;
    final key = await extKey?.asKeyData(
      cancelToken: cancelToken,
      options: barePoleOptions,
    );

    // 下载ts文件列表
    final playlist = [...?m3u8.playlist];

    var total = 0;
    var received = 0;
    final onReceiveProgress = options?.onReceiveProgress;
    if (onReceiveProgress != null) {
      total = await dio.contentLengths(
        playlist.map((e) => e.uri),
        cancelToken: cancelToken,
        options: barePoleOptions,
      );
    }
    if (total != 0) {
      onReceiveProgress?.call(received, total);
    }

    for (var value in playlist) {
      if (isCancelled) {
        break;
      }
      final bytes = await dio.asBytes(
        value.uri,
        cancelToken: cancelToken,
        options: options,
        onData: (value) {
          received += value.length;
          onReceiveProgress?.call(received, total);
        },
      );
      if (bytes == null) {
        continue;
      }
      onData(decrypt(bytes, key, extKey?.iv));
    }
  }
}
