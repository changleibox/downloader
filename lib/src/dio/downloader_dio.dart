/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'entry_stub.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'entry/downloader_dio_for_browser.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'entry/downloader_dio_for_native.dart';

/// Created by changlei on 2021/7/30.
///
/// 下载管理器专用[Dio]
class DownloaderDio with DioMixin implements Dio {
  /// 构造函数
  factory DownloaderDio([BaseOptions? options]) => createDio(options);
}

const _capacity = 2;

// 正在等待的队列
final _waitingQueue = ListQueue<Future>(_capacity);

// 正在进行的队列
final _ongoingQueue = ListQueue<Future>(_capacity);

/// 扩展dio
/// 为了防止一次性请求太多，我们限制最多只能进行[_capacity]个请求
mixin DownloaderDioMixin on DioMixin {
  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) async {
    final future = super.fetch<T>(requestOptions);
    // 当正在进行的请求达到上限，则把新进来的请求放在等待队列中，等待进行中队列请求完成
    if (_ongoingQueue.length < _capacity && _waitingQueue.isEmpty) {
      _ongoingQueue.add(future);
    } else {
      _waitingQueue.add(future);
    }
    await compute(_fetch, future);
    return future.whenComplete(() {
      _ongoingQueue.removeFirst();
      if (_waitingQueue.isNotEmpty) {
        _ongoingQueue.add(_waitingQueue.removeFirst());
      }
      print(_ongoingQueue.length);
    });
  }

  static void _fetch(Future? future) {
    while (_waitingQueue.contains(future)) {}
  }
}
