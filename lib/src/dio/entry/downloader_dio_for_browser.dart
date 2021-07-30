/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'package:dio/browser_imp.dart';
import 'package:dio/dio.dart';
import 'package:downloader/src/dio/downloader_dio.dart';

/// 创建dio
DownloaderDio createDio([BaseOptions? options]) => DownloaderDioForBrowser(options);

/// Created by changlei on 2021/7/30.
///
/// 用于浏览器
class DownloaderDioForBrowser extends DioForBrowser with DownloaderDioMixin implements DownloaderDio {
  /// Create Dio instance with default [Options].
  /// It's mostly just one Dio instance in your application.
  DownloaderDioForBrowser([BaseOptions? options]) : super(options);
}
