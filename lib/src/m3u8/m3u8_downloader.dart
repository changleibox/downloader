/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/src/dio/request.dart';
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
    ProgressCallback? onReceiveProgress,
    ValueChanged<Headers>? onHeaders,
  }) : super(
          url: url,
          onReceiveProgress: onReceiveProgress,
          onHeaders: onHeaders,
        );

  @override
  Future<void> onDownload(String url, ValueChanged<Uint8List> onData) async {
    var m3u8 = await M3u8.parse(url);
    final streamInf = m3u8?.streamInf;
    if (streamInf?.isNotEmpty == true) {
      m3u8 = await M3u8.parse(streamInf!.first.uri);
    }
    if (m3u8 == null) {
      return null;
    }

    final key = m3u8.key;
    final keyData = await key?.keyData;

    // 下载ts文件列表
    final playlist = [...?m3u8.playlist];

    var total = 0;
    var received = 0;
    if (onReceiveProgress != null) {
      total = await dio.contentLengths(
        playlist.map((e) => e.uri),
        cancelToken: cancelToken,
        onHeaders: onHeaders,
      );
    }
    if (total != 0) {
      onReceiveProgress?.call(received, total);
    }

    for (var value in playlist) {
      if (isCancelled) {
        break;
      }
      final data = await dio.asBytes(
        value.uri,
        cancelToken: cancelToken,
        onHeaders: onHeaders,
        onData: (value) {
          received += value.length;
          onReceiveProgress?.call(received, total);
        },
      );
      if (data == null) {
        continue;
      }
      onData(decrypt(data, keyData, key?.iv));
    }
  }
}
