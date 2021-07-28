/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:downloader/src/m3u8.dart';
import 'package:downloader/src/request.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const _downloader = M3u8Downloader._();

/// Created by changlei on 2021/7/27.
///
/// .m3u8下载器
class M3u8Downloader {
  const M3u8Downloader._();

  /// 下载
  static Future<String?> download(
    String url, {
    ProgressCallback? progress,
    CancelToken? cancelToken,
  }) async {
    return _downloader._download(
      url: url,
      targetDirectory: await getTemporaryDirectory(),
      progress: progress,
      cancelToken: cancelToken,
    );
  }

  /// download
  Future<String?> _download({
    required String url,
    required Directory targetDirectory,
    ProgressCallback? progress,
    CancelToken? cancelToken,
  }) async {
    var m3u8 = await M3u8.read(url);
    final streamInf = m3u8?.streamInf;
    if (streamInf?.isNotEmpty == true) {
      m3u8 = await M3u8.read(streamInf!.first.uri);
    }
    if (m3u8 == null) {
      return null;
    }

    // 合并下载后的ts文件
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final target = File(path.join(targetDirectory.path, '$timestamp.mp4'));
    if (target.existsSync()) {
      target.deleteSync();
    }
    target.createSync(recursive: true);
    final ioSink = target.openWrite();

    try {
      final key = m3u8.key;
      final keyData = await key?.keyData;

      // 下载ts文件列表
      final playlist = [...?m3u8.playlist];
      for (var value in playlist) {
        final data = await downloadToBytes(value.uri);
        if (data == null) {
          continue;
        }
        ioSink.add(decrypt(data, keyData, key?.iv));
      }
      return target.path;
    } catch (e) {
      target.deleteSync();
      rethrow;
    } finally {
      await ioSink.flush();
      await ioSink.close();
    }
  }
}
