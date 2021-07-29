import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/src/downloader.dart';
import 'package:downloader/src/request.dart';
import 'package:flutter/foundation.dart';

/// Created by changlei on 2021/7/29.
///
/// 通用下载器
class UniversalDownloader extends Downloader {
  /// 构造函数
  UniversalDownloader({
    required String url,
    ProgressCallback? onReceiveProgress,
  }) : super(url: url, onReceiveProgress: onReceiveProgress);

  @override
  Future<void> onDownload(String url, ValueChanged<Uint8List> onData) async {
    await requestAsBytes(
      url,
      onReceive: onData,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }
}
