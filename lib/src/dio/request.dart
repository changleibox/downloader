/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'package:dio/dio.dart';
import 'package:downloader/src/dio/downloader_dio.dart';

const _timeout = Duration(hours: 24);

/// Created by changlei on 2021/7/28.
///
/// 网络请求
final dio = DownloaderDio(
  BaseOptions(
    connectTimeout: _timeout.inMilliseconds,
    sendTimeout: _timeout.inMilliseconds,
    receiveTimeout: _timeout.inMilliseconds,
    followRedirects: true,
    maxRedirects: 10,
    receiveDataWhenStatusError: true,
  ),
);

/// 可以给下载管理器设置过滤器
Interceptors get interceptors => dio.interceptors;
