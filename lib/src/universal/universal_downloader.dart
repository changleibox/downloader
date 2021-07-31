/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:downloader/downloader.dart';
import 'package:downloader/src/dio/downloader_dio.dart';
import 'package:downloader/src/dio/request.dart';
import 'package:downloader/src/downloader.dart';
import 'package:flutter/foundation.dart';

/// Created by changlei on 2021/7/29.
///
/// 通用下载器
class UniversalDownloader extends Downloader {
  /// 构造函数
  UniversalDownloader({
    required String url,
    ProgressCallback? onReceiveProgress,
    FutureOrValueChanged<void, Headers>? onHeaders,
    Map<String, dynamic>? queryParameters,
    String lengthHeader = Headers.contentLengthHeader,
    dynamic data,
    Options? options,
  }) : super(
          url: url,
          onReceiveProgress: onReceiveProgress,
          onHeaders: onHeaders,
          queryParameters: queryParameters,
          lengthHeader: lengthHeader,
          data: data,
          options: options,
        );

  @override
  Future<void> onDownload(String url, ValueChanged<Uint8List> onData) async {
    await dio.asStream(
      url,
      onData: onData,
      cancelOnError: true,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      onHeaders: onHeaders,
      queryParameters: queryParameters,
      lengthHeader: lengthHeader,
      options: options,
      data: data,
    );
  }
}
