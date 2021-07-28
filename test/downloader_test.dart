import 'package:downloader/src/m3u8_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds one to input values', () async {
    await M3u8.load('https://vod4.buycar5.cn/20210718/lx14hBDC/index.m3u8');
  });
}
