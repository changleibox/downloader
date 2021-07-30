/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'package:dio/dio.dart';
import 'package:dio/native_imp.dart';
import 'package:downloader/src/dio/downloader_dio.dart';

/// 创建dio
DownloaderDio createDio([BaseOptions? options]) => DownloaderDioForNative(options);

/// Created by changlei on 2021/7/30.
///
/// 用于移动端
class DownloaderDioForNative extends DioForNative with DownloaderDioMixin implements DownloaderDio {
  /// Create Dio instance with default [BaseOptions].
  /// It is recommended that an application use only the same DIO singleton.
  DownloaderDioForNative([BaseOptions? baseOptions]) : super(baseOptions);
}
