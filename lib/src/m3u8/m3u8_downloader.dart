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
  }) : super(url: url, onReceiveProgress: onReceiveProgress);

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

    final total = await requestLength(
      playlist.map((e) => e.uri),
      cancelToken: cancelToken,
    );
    var received = 0;

    for (var value in playlist) {
      if (isCancelled) {
        break;
      }
      final data = await requestAsBytes(
        value.uri,
        cancelToken: cancelToken,
        onReceive: (value) {
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
