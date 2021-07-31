/*
 * Copyright (c) 2021 CHANGLEI. All rights reserved.
 */

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:downloader/downloader.dart';
import 'package:downloader/src/dio/request.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path/path.dart' as path;

const _extInf = '#EXTINF';
const _extXStreamInf = '#EXT-X-STREAM-INF';

final _httpHeaderRegExp = RegExp(r'http|https://');

/// Created by changlei on 2021/7/28.
///
/// m3u8
/// M3u8文件内容
class M3u8 {
  /// 构造函数
  const M3u8({
    this.version,
    this.playlist,
    this.byteRange,
    this.discontinuity,
    this.key,
    this.map,
    this.programDateTime,
    this.dateRange,
    this.targetDuration,
    this.mediaSequence,
    this.discontinuitySequence,
    this.playlistType,
    this.framesOnly,
    this.media,
    this.streamInf,
    this.frameStreamInf,
    this.sessionData,
    this.sessionKey,
    this.start,
  });

  /// 表示 HLS 的协议版本号，该标签与流媒体的兼容性相关。该标签为全局作用域，使能整个 m3u8 文件；
  /// 每个 m3u8 文件内最多只能出现一个该标签定义。如果 m3u8 文件不包含该标签，则默认为协议的第一个版本。
  final String? version;

  /// 每个切片 URI 前面都有一系列媒体片段标签对其进行描述。
  /// 有些片段标签只对其后切片资源有效；有些片段标签对其后所有切片都有效，直到后续遇到另一个该标签描述。
  /// 媒体片段类型标签不能出现在主播放列表（Master Playlist）中
  final Playlist? playlist;

  /// 该标签表示接下来的切片资源是其后 URI 指定的媒体片段资源的局部范围（即截取 URI 媒体资源部分内容作为下一个切片）。
  /// 该标签只对其后一个 URI 起作用
  final String? byteRange;

  /// 该标签表明其前一个切片与下一个切片之间存在中断
  final String? discontinuity;

  /// 媒体片段可以进行加密，而该标签可以指定解密方法。
  /// 该标签对所有 媒体片段 和 由标签 EXT-X-MAP 声明的围绕其间的所有 媒体初始化块（Meida Initialization Section） 都起作用，
  /// 直到遇到下一个 EXT-X-KEY（若 m3u8 文件只有一个 EXT-X-KEY 标签，则其作用于所有媒体片段）。
  /// 多个 EXT-X-KEY 标签如果最终生成的是同样的秘钥，则他们都可作用于同一个媒体片段
  final ExtKey? key;

  /// 该标签指明了获取媒体初始化块（Meida Initialization Section）的方法。
  /// 该标签对其后所有媒体片段生效，直至遇到另一个 EXT-X-MAP 标签。
  final ExtMap? map;

  /// 该标签使用一个绝对日期/时间表明第一个样本片段的取样时间。
  final String? programDateTime;

  /// 该标签定义了一系列由属性/值对组成的日期范围。
  final ExtDateRange? dateRange;

  /// 表示每个视频分段最大的时长（单位秒）。
  /// 该标签为必选标签。
  final Duration? targetDuration;

  /// 表示播放列表第一个 URL 片段文件的序列号。
  /// 每个媒体片段 URL 都拥有一个唯一的整型序列号。
  /// 每个媒体片段序列号按出现顺序依次加 1。
  /// 如果该标签未指定，则默认序列号从 0 开始。
  /// 媒体片段序列号与片段文件名无关。
  /// 其中：参数number即为切片序列号。
  final int? mediaSequence;

  /// 该标签使能同步相同流的不同 Rendition 和 具备 EXT-X-DISCONTINUITY 标签的不同备份流。
  /// 其中：参数number为一个十进制整型数值。
  /// 如果播放列表未设置 EXT-X-DISCONTINUITY-SEQUENCE 标签，那么对于第一个切片的中断序列号应当为 0。
  final int? discontinuitySequence;

  /// 表明流媒体类型。全局生效。
  /// 该标签为可选标签。
  final PlaylistType? playlistType;

  /// 该标签表示每个媒体片段都是一个 I-frame。I-frames 帧视屏编码不依赖于其他帧数，因此可以通过 I-frame 进行快速播放，急速翻转等操作。
  /// 该标签全局生效。
  /// 如果播放列表设置了 EXT-X-I-FRAMES-ONLY，那么切片的时长（EXTINF 标签的值）即为当前切片 I-frame 帧开始到下一个 I-frame 帧出现的时长。
  /// 媒体资源如果包含 I-frame 切片，那么必须提供媒体初始化块或者通过 EXT-X-MAP 标签提供媒体初始化块的获取途径，这样客户端就能通过这些 I-frame 切片以任意顺序进行加载和解码。
  /// 如果 I-frame 切片设置了 EXT-BYTERANGE，那么就绝对不能提供媒体初始化块。
  /// 使用 EXT-X-I-FRAMES-ONLY 要求的兼容版本号 EXT-X-VERSION 大于等于 4。
  final bool? framesOnly;

  /// 用于指定相同内容的可替换的多语言翻译播放媒体列表资源。
  /// 比如，通过三个 EXT-X-MEIDA 标签，可以提供包含英文，法语和西班牙语版本的相同内容的音频资源，或者通过两个 EXT-X-MEDIA 提供两个不同拍摄角度的视屏资源。
  final ExtMedia? media;

  /// 该属性指定了一个备份源。该属性值提供了该备份源的相关信息。
  final MasterPlaylist? streamInf;

  /// 该标签表明媒体播放列表文件包含多种媒体资源的 I-frame 帧。
  final ExtFrameStreamInf? frameStreamInf;

  /// 该标签允许主播放列表携带任意 session 数据。
  /// 该标签为可选参数。
  final ExtSessionData? sessionData;

  /// 该标签允许主播放列表（Master Playlist）指定媒体播放列表（Meida Playlist）的加密密钥。这使得客户端可以预先加载这些密钥，而无需从媒体播放列表中获取。
  /// 该标签为可选参数。
  final ExtKey? sessionKey;

  /// 该标签表示播放列表播放起始位置。
  /// 默认情况下，客户端开启一个播放会话时，应当使用该标签指定的位置进行播放。
  /// 该标签为可选标签。
  final ExtStart? start;

  /// 加载M3U8格式文件
  static Future<M3u8?> parse(
    String url, {
    CancelToken? cancelToken,
    DownloadOptions? options,
  }) async {
    final data = await dio.asBytes(
      url,
      cancelToken: cancelToken,
      options: options,
    );
    if (data == null) {
      return null;
    }
    final lines = String.fromCharCodes(data).split('\n');

    final attributes = <String, String>{};
    final iterator = lines.iterator;
    while (iterator.moveNext()) {
      final line = iterator.current;
      if (line == '#EXTM3U' || (line.startsWith('#') && !line.startsWith('#EXT')) || line.isEmpty) {
        continue;
      }
      if (line == '#EXT-X-ENDLIST') {
        break;
      }
      final splitIndex = line.indexOf(':');
      final invalid = splitIndex < 0 || splitIndex >= line.length - 1;
      if (line.startsWith('#') && invalid) {
        continue;
      }
      final key = line.substring(0, splitIndex);
      final value = line.substring(splitIndex + 1);
      final buffer = StringBuffer(value);
      if (line.startsWith(RegExp('$_extInf|$_extXStreamInf')) && iterator.moveNext()) {
        buffer.write('|');
        buffer.write(_mergeUrl(url, iterator.current));
      }
      final dynamic attributeValue = attributes[key];
      final appendedValues = <dynamic>[];
      if (attributeValue != null) {
        appendedValues.add(attributeValue);
      }
      appendedValues.add(buffer);
      attributes[key] = appendedValues.join('\n');
    }

    return M3u8(
      version: attributes['#EXT-X-VERSION'],
      targetDuration: _tryParseDuration(attributes['#EXT-X-TARGETDURATION']),
      playlistType: _convertPlaylistType(attributes['#EXT-X-PLAYLIST-TYPE']),
      mediaSequence: _tryParseInt(attributes['#EXT-X-MEDIA-SEQUENCE']),
      byteRange: attributes['#EXT-X-BYTERANGE'],
      discontinuity: attributes['#EXT-X-DISCONTINUITY'],
      key: ExtKey.from(attributes['#EXT-X-KEY']),
      map: ExtMap.from(attributes['#EXT-X-MAP']),
      programDateTime: attributes['#EXT-X-PROGRAM-DATE-TIME'],
      dateRange: ExtDateRange.from(attributes['#EXT-X-DATERANGE']),
      discontinuitySequence: _tryParseInt(attributes['#EXT-X-DISCONTINUITY-SEQUENCE']),
      framesOnly: attributes.containsKey('#EXT-X-I-FRAMES-ONLY'),
      media: ExtMedia.from(attributes['#EXT-X-MEDIA']),
      streamInf: MasterPlaylist.from(attributes[_extXStreamInf]),
      frameStreamInf: ExtFrameStreamInf.from(attributes['#EXT-X-I-FRAME-STREAM-INF']),
      sessionData: ExtSessionData.from(attributes['#EXT-X-SESSION-DATA']),
      sessionKey: ExtKey.from(attributes['#EXT-X-SESSION-KEY']),
      playlist: Playlist.from(attributes[_extInf]),
      start: ExtStart.from(attributes['#EXT-X-START']),
    );
  }
}

/// 该属性指定了一个备份源。该属性值提供了该备份源的相关信息。
class ExtStreamInf {
  /// 构造函数
  const ExtStreamInf({
    required this.uri,
    required this.bandWidth,
    this.averageBandWidth,
    this.codecs,
    this.resolution,
    this.frameRate,
    this.hdcpLevel,
    this.audio,
    this.video,
    this.subtitles,
    this.closedCaptions,
  });

  /// 按照[value]初始化
  static ExtStreamInf? from(String? value) {
    if (value == null) {
      return null;
    }
    final split = value.split('|');
    final map = _convertAttributeMap(split.first)!;
    return ExtStreamInf(
      uri: split.last,
      bandWidth: _tryParseInt(map['BANDWIDTH'])!,
      averageBandWidth: _tryParseInt(map['AVERAGE-BANDWIDTH']),
      codecs: map['CODECS']?.split(','),
      resolution: _tryParseSize(map['RESOLUTION']),
      frameRate: _tryParseDouble(map['FRAME-RATE']),
      hdcpLevel: _convertHdcpLevel(map['HDCP-LEVEL']),
      audio: map['AUDIO'],
      video: map['VIDEO'],
      subtitles: map['SUBTITLES'],
      closedCaptions: map['CLOSED-CAPTIONS'],
    );
  }

  /// 指定的媒体播放列表携带了该标签指定的翻译备份源
  /// URI 为必选参数。
  final String uri;

  /// 该属性为每秒传输的比特数，也即带宽。代表该备份流的巅峰速率
  /// 该属性为必选参数。
  final int bandWidth;

  /// 该属性为备份流的平均切片传输速率
  /// 该属性为可选参数。
  final int? averageBandWidth;

  /// 双引号包裹的包含由逗号分隔的格式列表组成的字符串
  /// 每个 EXT-X-STREAM-INF 标签都应当携带 CODECS 属性。
  final List<String>? codecs;

  /// 该属性描述备份流视屏源的最佳像素方案
  /// 该属性为可选参数，但对于包含视屏源的备份流建议增加该属性设置。
  final Size? resolution;

  /// 该属性用一个十进制浮点型数值作为描述备份流所有视屏最大帧率。
  /// 对于备份流中任意视屏源帧数超过每秒 30 帧的，应当增加该属性设置。
  /// 该属性为可选参数，但对于包含视屏源的备份流建议增加该属性设置。
  final double? frameRate;

  /// 该属性值为一个可枚举字符串。
  /// 其有效值为TYPE-0或NONE。
  /// 值为TYPE-0表示该备份流可能会播放失败，除非输出被高带宽数字内容保护（HDCP）。
  /// 值为NONE表示流内容无需输出拷贝保护。
  /// 使用不同程度的 HDCP 加密备份流应当使用不同的媒体加密密钥。
  /// 该属性为可选参数。在缺乏 HDCP 可能存在播放失败的情况下，应当提供该属性。
  final HdcpLevel? hdcpLevel;

  /// 属性值由双引号包裹，其值必须与定义在主播放列表某处的设置了 TYPE 属性值为 AUDIO 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 该属性为可选参数。
  final String? audio;

  /// 属性值由双引号包裹，其值必须与定义在主播放列表某处的设置了 TYPE 属性值为 VIDEO 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 该属性为可选参数。
  final String? video;

  /// 属性值由双引号包裹，其值必须与定义在主播放列表某处的设置了 TYPE 属性值为 SUBTITLES 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 该属性为可选参数。
  final String? subtitles;

  /// 该属性值可以是一个双引号包裹的字符串或NONE。
  /// 如果其值为一个字符串，则必须与定义在主播放列表某处的设置了 TYPE 属性值为 CLOSED-CAPTIONS 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 如果其值为NONE，则所有的 ext-x-stream-inf 标签必须同样将该属性设置NONE，表示主播放列表备份流均没有关闭的标题。对于某个备份流具备关闭标题，另一个备份流不具备关闭标题可能会触发播放中断。
  /// 该属性为可选参数。
  final String? closedCaptions;
}

/// playlist
class MasterPlaylist extends ListBase<ExtStreamInf> {
  MasterPlaylist._(List<ExtStreamInf>? list) {
    if (list != null) {
      _list.addAll(list);
    }
  }

  /// 按照[value]初始化
  static MasterPlaylist? from(String? value) {
    if (value == null) {
      return null;
    }
    final list = <ExtStreamInf>[];
    final playlistLines = value.split('\n');
    for (var line in playlistLines) {
      final streamInf = ExtStreamInf.from(line);
      if (streamInf == null) {
        continue;
      }
      list.add(streamInf);
    }
    return MasterPlaylist._(list);
  }

  final _list = <ExtStreamInf>[];

  @override
  int get length => _list.length;

  @override
  set length(int newLength) => _list.length = newLength;

  @override
  ExtStreamInf operator [](int index) {
    return _list[index];
  }

  @override
  void operator []=(int index, ExtStreamInf value) {
    _list[index] = value;
  }
}

/// 该标签表明媒体播放列表文件包含多种媒体资源的 I-frame 帧。
class ExtFrameStreamInf {
  /// 构造函数
  const ExtFrameStreamInf({
    required this.uri,
    this.frameRate,
    this.audio,
    this.subtitles,
    this.closedCaptions,
  });

  /// 按照[map]初始化
  static ExtFrameStreamInf? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    return ExtFrameStreamInf(
      uri: map['URI']!,
      frameRate: _tryParseDouble(map['FRAME-RATE']),
      audio: map['AUDIO'],
      subtitles: map['SUBTITLES'],
      closedCaptions: map['CLOSED-CAPTIONS'],
    );
  }

  /// 指定的媒体播放列表携带了该标签指定的翻译备份源
  /// URI 为必选参数。
  final String uri;

  /// 该属性用一个十进制浮点型数值作为描述备份流所有视屏最大帧率。
  /// 对于备份流中任意视屏源帧数超过每秒 30 帧的，应当增加该属性设置。
  /// 该属性为可选参数，但对于包含视屏源的备份流建议增加该属性设置。
  final double? frameRate;

  /// 属性值由双引号包裹，其值必须与定义在主播放列表某处的设置了 TYPE 属性值为 AUDIO 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 该属性为可选参数。
  final String? audio;

  /// 属性值由双引号包裹，其值必须与定义在主播放列表某处的设置了 TYPE 属性值为 SUBTITLES 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 该属性为可选参数。
  final String? subtitles;

  /// 该属性值可以是一个双引号包裹的字符串或NONE。
  /// 如果其值为一个字符串，则必须与定义在主播放列表某处的设置了 TYPE 属性值为 CLOSED-CAPTIONS 的 EXT-X-MEDIA 标签的 GROUP-ID 属性值相匹配。
  /// 如果其值为NONE，则所有的 ext-x-stream-inf 标签必须同样将该属性设置NONE，表示主播放列表备份流均没有关闭的标题。对于某个备份流具备关闭标题，另一个备份流不具备关闭标题可能会触发播放中断。
  /// 该属性为可选参数。
  final String? closedCaptions;
}

/// 信息
class ExtInf {
  /// 构造函数
  const ExtInf({required this.uri, this.duration, this.title});

  /// uri
  final String uri;

  /// 媒体片段时长
  final Duration? duration;

  /// 标题
  final String? title;
}

/// playlist
class Playlist extends ListBase<ExtInf> {
  Playlist._(List<ExtInf>? list) {
    if (list != null) {
      _list.addAll(list);
    }
  }

  /// 按照[value]初始化
  static Playlist? from(String? value) {
    if (value == null) {
      return null;
    }
    final list = <ExtInf>[];
    final playlistLines = value.split('\n');
    for (var line in playlistLines) {
      final split = line.split('|');
      final info = split.first.split(',');
      list.add(ExtInf(
        uri: split.last,
        title: info.last,
        duration: _tryParseDuration(info.first),
      ));
    }
    return Playlist._(list);
  }

  final _list = <ExtInf>[];

  @override
  int get length => _list.length;

  @override
  set length(int newLength) => _list.length = newLength;

  @override
  ExtInf operator [](int index) {
    return _list[index];
  }

  @override
  void operator []=(int index, ExtInf value) {
    _list[index] = value;
  }
}

/// key
class ExtKey {
  /// 构造函数
  const ExtKey({
    required this.uri,
    required this.method,
    this.iv,
    this.keyFormat,
    this.keyFormatVersions,
  });

  /// 按照[map]初始化
  static ExtKey? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    return ExtKey(
      uri: map['URI']!,
      method: _convertKeyMethod(map['METHOD']),
      iv: map['IV'],
      keyFormat: map['KEYFORMAT'],
      keyFormatVersions: map['KEYFORMATVERSIONS'],
    );
  }

  /// 获取key的内容
  Future<Uint8List?> asKeyData({
    CancelToken? cancelToken,
    DownloadOptions? options,
  }) async {
    if (method == KeyMethod.none) {
      return null;
    }
    return dio.asBytes(
      uri,
      cancelToken: cancelToken,
      options: options,
    );
  }

  /// 指定密钥路径。
  /// 该密钥是一个 16 字节的数据。
  /// 该键是必须参数，除非 METHOD 为NONE。
  final String uri;

  /// 该值是一个可枚举的字符串，指定了加密方法。
  /// 该键是必须参数。其值可为NONE，AES-128，SAMPLE-AES当中的一个。
  /// 其中：
  /// NONE：表示切片未进行加密（此时其他属性不能出现）；
  /// AES-128：表示表示使用 AES-128 进行加密。
  /// SAMPLE-AES：意味着媒体片段当中包含样本媒体，比如音频或视频，它们使用 AES-128 进行加密。这种情况下 IV 属性可以出现也可以不出现。
  final KeyMethod method;

  /// 该值是一个 128 位的十六进制数值。
  /// AES-128 要求使用相同的 16字节 IV 值进行加密和解密。使用不同的 IV 值可以增强密码强度。
  /// 如果属性列表出现 IV，则使用该值；如果未出现，则默认使用媒体片段序列号（即 EXT-X-MEDIA-SEQUENCE）作为其 IV 值，使用大端字节序，往左填充 0 直到序列号满足 16 字节（128 位）。
  final String? iv;

  /// 由双引号包裹的字符串，标识密钥在密钥文件中的存储方式（密钥文件中的 AES-128 密钥是以二进制方式存储的16个字节的密钥）。
  /// 该属性为可选参数，其默认值为"identity"。
  /// 使用该属性要求兼容版本号 EXT-X-VERSION 大于等于 5。
  final String? keyFormat;

  /// 由一个或多个被/分割的正整型数值构成的带引号的字符串（比如："1"，"1/2"，"1/2/5"）。
  /// 如果有一个或多特定的 KEYFORMT 版本被定义了，则可使用该属性指示具体版本进行编译。
  /// 该属性为可选参数，其默认值为"1"。
  /// 使用该属性要求兼容版本号 EXT-X-VERSION 大于等于 5。
  final String? keyFormatVersions;
}

/// 使用不同程度的 HDCP 加密备份流应当使用不同的媒体加密密钥。
/// 该属性为可选参数。在缺乏 HDCP 可能存在播放失败的情况下，应当提供该属性。
enum HdcpLevel {
  /// 值为TYPE-0表示该备份流可能会播放失败，除非输出被高带宽数字内容保护（HDCP）。
  type0,

  /// 值为NONE表示流内容无需输出拷贝保护。
  none,
}

HdcpLevel _convertHdcpLevel(dynamic value) {
  switch (value) {
    case 'TYPE-0':
      return HdcpLevel.type0;
  }
  return HdcpLevel.none;
}

/// 该值是一个可枚举的字符串，指定了加密方法。
/// 该键是必须参数。其值可为NONE，AES-128，SAMPLE-AES当中的一个。
enum KeyMethod {
  /// 表示切片未进行加密（此时其他属性不能出现）；
  none,

  /// 表示表示使用 AES-128 进行加密。
  aes128,

  /// 意味着媒体片段当中包含样本媒体，比如音频或视频，它们使用 AES-128 进行加密。这种情况下 IV 属性可以出现也可以不出现。
  sampleAes,
}

KeyMethod _convertKeyMethod(dynamic value) {
  switch (value) {
    case 'AES-128':
      return KeyMethod.aes128;
    case 'SAMPLE-AES':
      return KeyMethod.sampleAes;
  }
  return KeyMethod.none;
}

/// 该标签指明了获取媒体初始化块（Meida Initialization Section）的方法。
/// 该标签对其后所有媒体片段生效，直至遇到另一个 EXT-X-MAP 标签。
class ExtMap {
  /// 构造函数
  const ExtMap({
    required this.uri,
    this.byteRange,
  });

  /// 按照[map]初始化
  static ExtMap? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    return ExtMap(
      uri: map['URI']!,
      byteRange: map['BYTERANGE'],
    );
  }

  /// 由引号包裹的字符串，指定了包含媒体初始化块的资源的路径。该属性为必选参数。
  final String uri;

  /// 由引号包裹的字符串，指定了媒体初始化块在 URI 指定的资源的位置（片段）。
  /// 该属性指定的范围应当只包含媒体初始化块。
  /// 该属性为可选参数，如果未指定，则表示 URI 指定的资源就是全部的媒体初始化块。
  final String? byteRange;
}

/// 该标签定义了一系列由属性/值对组成的日期范围。
class ExtDateRange {
  /// 构造函数
  const ExtDateRange({
    required this.id,
    this.classX,
    required this.startDate,
    this.endDate,
    this.duration,
    this.plannedDuration,
    this.clientAttributes,
    this.scte35Cmd,
    this.scte35Out,
    this.scte35In,
    this.endOnNext,
  });

  /// 按照[map]初始化
  static ExtDateRange? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    final keys = map.keys.where((element) {
      return element.startsWith('X-');
    });
    final clientAttributes = <String, String?>{};
    for (var key in keys) {
      clientAttributes[key] = map[key];
    }
    return ExtDateRange(
      id: map['ID']!,
      classX: map['CLASS'],
      startDate: map['START-DATE']!,
      endDate: map['END-DATE'],
      duration: _tryParseDuration(map['DURATION']),
      plannedDuration: _tryParseDuration(map['PLANNED-DURATION']),
      clientAttributes: clientAttributes,
      scte35Cmd: map['SCTE35-CMD'],
      scte35Out: map['SCTE35-OUT'],
      scte35In: map['SCTE35-IN'],
      endOnNext: map['END-ON-NEXT'],
    );
  }

  /// 双引号包裹的唯一指明日期范围的标识。
  // 该属性为必选参数。
  final String id;

  /// 双引号包裹的由客户定义的一系列属性与与之对应的语意值。
  /// 所有拥有同一 CLASS 属性的日期范围必须遵守对应的语意。
  /// 该属性为可选参数。
  final String? classX;

  /// 双引号包裹的日期范围起始值。
  /// 该属性为必选参数。
  final String startDate;

  /// 双引号包裹的日期范围结束值。
  /// 该属性值必须大于或等于 START-DATE。
  /// 该属性为可选参数。
  final String? endDate;

  /// 日期范围的持续时间是一个十进制浮点型数值类型（单位：秒）。
  /// 该属性值不能为负数。
  /// 当表达立即时间时，将该属性值设为 0 即可。
  /// 该属性为可选参数。
  final Duration? duration;

  /// 该属性为日期范围的期望持续时长。
  /// 其值为一个十进制浮点数值类型（单位：秒）。
  /// 该属性值不能为负数。
  /// 在预先无法得知真实持续时长的情况下，可使用该属性作为日期范围的期望预估时长。
  /// 该属性为可选参数。
  final Duration? plannedDuration;

  /// X-前缀是预留给客户端自定义属性的命名空间。
  /// 客户端自定义属性名时，应当使用反向 DNS（reverse-DNS）语法来避免冲突。
  /// 自定义属性值必须是使用双引号包裹的字符串，或者是十六进制序列，或者是十进制浮点数，比如：X-COM-EXAMPLE-AD-ID="XYZ123"。
  /// 该属性为可选参数。
  final Map<String, String?>? clientAttributes;

  /// 用于携带 SCET-35 数据。
  /// 该属性为可选参数。
  final String? scte35Cmd;

  /// 用于携带 SCET-35 数据。
  /// 该属性为可选参数。
  final String? scte35Out;

  /// 用于携带 SCET-35 数据。
  /// 该属性为可选参数。
  final String? scte35In;

  /// 该属性值为一个可枚举字符串，其值必须为YES。
  /// 该属性表明达到该范围末尾，也即等于后续范围的起始位置 START-DATE。后续范围是指具有相同 CLASS 的，在该标签 START-DATE 之后的具有最早 START-DATE 值的日期范围。
  /// 该属性时可选参数。
  final String? endOnNext;
}

/// 表明流媒体类型。全局生效。
enum PlaylistType {
  /// 即 Video on Demand，表示该视屏流为点播源，因此服务器不能更改该 m3u8 文件；
  vod,

  /// 表示该视频流为直播源，因此服务器不能更改或删除该文件任意部分内容（但是可以在文件末尾添加新内容）。
  /// 注：VOD 文件通常带有 EXT-X-ENDLIST 标签，因为其为点播源，不会改变；而 EVEVT 文件初始化时一般不会有 EXT-X-ENDLIST 标签，
  /// 暗示有新的文件会添加到播放列表末尾，因此也需要客户端定时获取该 m3u8 文件，以获取新的媒体片段资源，直到访问到 EXT-X-ENDLIST 标签才停止）。
  event,
}

PlaylistType? _convertPlaylistType(dynamic value) {
  switch (value) {
    case 'VOD':
      return PlaylistType.vod;
    case 'EVENT':
      return PlaylistType.event;
  }
  return null;
}

/// 用于指定相同内容的可替换的多语言翻译播放媒体列表资源。
/// 比如，通过三个 EXT-X-MEIDA 标签，可以提供包含英文，法语和西班牙语版本的相同内容的音频资源，或者通过两个 EXT-X-MEDIA 提供两个不同拍摄角度的视屏资源。
class ExtMedia {
  /// 构造函数
  const ExtMedia({
    this.uri,
    required this.type,
    required this.groupId,
    this.language,
    this.assocLanguage,
    required this.name,
    this.defaultX,
    this.autoSelect,
    this.forced,
    this.inStreamId,
    this.characteristics,
    this.channels,
  });

  /// 按照[map]初始化
  static ExtMedia? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    return ExtMedia(
      type: _convertMediaType(map['TYPE'])!,
      groupId: map['GROUP-ID']!,
      name: map['NAME']!,
      uri: map['URI'],
      language: map['LANGUAGE'],
      assocLanguage: map['ASSOC-LANGUAGE'],
      autoSelect: map['AUTOSELECT'] == 'YES',
      defaultX: map['DEFAULT'] == 'YES',
      forced: map['FORCED'] == 'YES',
      inStreamId: map['INSTREAM-ID'],
      characteristics: map['CHARACTERISTICS']?.split(','),
      channels: map['CHANNELS']?.split('/'),
    );
  }

  /// 双引号包裹的媒体资源播放列表路径。
  /// 如果 TYPE 属性值为 CLOSED-CAPTIONS，那么则不能提供 URI。
  /// 该属性为可选参数。
  final String? uri;

  /// 该属性值为一个可枚举字符串。
  /// 其值有如下四种：AUDIO，VIDEO，SUBTITLES，CLOSED-CAPTIONS。
  /// 通常使用的都是CLOSED-CAPTIONS。
  /// 该属性为必选参数。
  final MediaType type;

  /// 双引号包裹的字符串，表示多语言翻译流所属组。
  /// 该属性为必选参数
  final String groupId;

  /// 双引号包裹的字符串，用于指定流主要使用的语言。
  /// 该属性为可选参数。
  final String? language;

  /// 双引号包裹的字符串，其内包含一个语言标签，用于提供多语言流的其中一种语言版本。
  /// 该参数为可选参数。
  final String? assocLanguage;

  /// 双引号包裹的字符串，用于为翻译流提供可读的描述信息。
  /// 如果设置了 LANGUAGE 属性，那么也应当设置 NAME 属性。
  /// 该属性为必选参数。
  final String name;

  /// 该属性值为一个可枚举字符串。
  /// 可选值为YES和NO。
  /// 该属性未指定时默认值为NO。
  /// 如果该属性设为YES，那么客户端在缺乏其他可选信息时应当播放该翻译流。
  /// 该属性为可选参数。
  final bool? defaultX;

  /// 该属性值为一个可枚举字符串。
  /// 其有效值为YES或NO。
  /// 未指定时，默认设为NO。
  /// 如果该属性设置YES，那么客户端在用户没有显示进行设置时，可以选择播放该翻译流，因为其能配置当前播放环境，比如系统语言选择。
  /// 如果设置了该属性，那么当 DEFAULT 设置YES时，该属性也必须设置为YES。
  /// 该属性为可选参数。
  final bool? autoSelect;

  /// 该属性值为一个可枚举字符串。
  /// 其有效值为YES或NO。
  /// 未指定时，默认设为NO。
  /// 只有在设置了 TYPE 为 SUBTITLES 时，才可以设置该属性。
  /// 当该属性设为YES时，则暗示该翻译流包含重要内容。当设置了该属性，客户端应当选择播放匹配当前播放环境最佳的翻译流。
  /// 当该属性设为NO时，则表示该翻译流内容意图用于回复用户显示进行请求。
  /// 该属性为可选参数。
  final bool? forced;

  /// 由双引号包裹的字符串，用于指示切片的语言（Rendition）版本。
  /// 当 TYPE 设为 CLOSED-CAPTIONS 时，必须设置该属性。
  /// 其可选值为："CC1", "CC2", "CC3", "CC4" 和 "SERVICEn"（n的值为 1~63）。
  /// 对于其他 TYPE 值，该属性绝不能进行设置。
  final String? inStreamId;

  /// 由双引号包裹的由一个或多个由逗号分隔的 UTI 构成的字符串。
  /// 每个 UTI 表示一种翻译流的特征。
  /// 该属性可包含私有 UTI。
  /// 该属性为可选参数。
  final List<String>? characteristics;

  /// 由双引号包裹的有序，由反斜杠/分隔的参数列表组成的字符串。
  /// 所有音频 EXT-X-MEDIA 标签应当都设置 CHANNELS 属性。
  /// 如果主播放列表包含两个相同编码但是具有不同数目 channed 的翻译流，则必须设置 CHANNELS 属性；否则，CHANNELS 属性为可选参数。
  final List<String>? channels;
}

/// 该属性值为一个可枚举字符串
enum MediaType {
  /// audio
  audio,

  /// video
  video,

  /// subtitles
  subtitles,

  /// closedCaptions
  closedCaptions,
}

MediaType? _convertMediaType(dynamic value) {
  switch (value) {
    case 'AUDIO':
      return MediaType.audio;
    case 'VIDEO':
      return MediaType.video;
    case 'SUBTITLES':
      return MediaType.subtitles;
    case 'CLOSED-CAPTIONS':
      return MediaType.closedCaptions;
  }
}

/// 该标签允许主播放列表携带任意 session 数据。
class ExtSessionData {
  /// 构造函数
  const ExtSessionData({
    required this.dataId,
    this.value,
    this.uri,
    this.language,
  });

  /// 按照[map]初始化
  static ExtSessionData? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    return ExtSessionData(
      dataId: map['DATA-ID']!,
      value: map['VALUE'],
      uri: map['URI'],
      language: map['LANGUAGE'],
    );
  }

  /// 由双引号包裹的字符串，代表一个特定的数据值。
  /// 该属性应当使用反向 DNS 进行命名，如"com.example.movie.title"。然而，由于没有中央注册机构，所以可能出现冲突情况。
  /// 该属性为必选参数。
  final String dataId;

  /// 该属性值为一个双引号包裹的字符串，其包含 DATA-ID 指定的值。
  /// 如果设置了 LANGUAGE，则 VALUE 应当包含一个用该语言书写的可读字符串。
  final String? value;

  /// 由双引号包裹的 URI 字符串。由该 URI 指示的资源必选使用 JSON 格式，否则，客户端可能会解析失败。
  final String? uri;

  /// 由双引号包裹的，包含一个语言标签的字符串。指示了 VALUE 所使用的语言。
  final String? language;
}

/// 该标签表示播放列表播放起始位置。
/// 默认情况下，客户端开启一个播放会话时，应当使用该标签指定的位置进行播放。
class ExtStart {
  /// 构造函数
  const ExtStart({required this.timeOffset, this.precise});

  /// 按照[map]初始化
  static ExtStart? from(String? value) {
    if (value == null) {
      return null;
    }
    final map = _convertAttributeMap(value)!;
    return ExtStart(
      timeOffset: _tryParseDuration(map['TIME-OFFSET'])!,
      precise: map['PRECISE'] == 'YES',
    );
  }

  /// 该属性值为一个带符号十进制浮点数（单位：秒）。
  /// 一个正数表示以播放列表起始位置开始的时间偏移量。
  /// 一个负数表示播放列表上一个媒体片段最后位置往前的时间偏移量。
  /// 该属性的绝对值应当不超过播放列表的时长。如果超过，则表示到达文件结尾（数值为正数），或者达到文件起始（数值为负数）。
  /// 如果播放列表不包含 EXT-X-ENDLIST 标签，那么 TIME-OFFSET 属性值不应当在播放文件末尾三个切片时长之内。
  final Duration timeOffset;

  /// 该值为一个可枚举字符串。
  /// 有效的取值为YES 或 NO。
  /// 如果值为YES，客户端应当播放包含 TIME-OFFSET 的媒体片段，但不要渲染该块内优先于 TIME-OFFSET 的样本块。
  /// 如果值为NO，客户端应当尝试渲染在媒体片段内的所有样本块。
  /// 该属性为可选参数，未指定则认为NO。
  final bool? precise;
}

int? _tryParseInt(dynamic value, [int? defaultValue]) {
  if (value == null) {
    return defaultValue;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString()) ?? defaultValue;
}

double? _tryParseDouble(dynamic value, [double? defaultValue]) {
  if (value == null) {
    return defaultValue;
  }
  if (value is double) {
    return value;
  }
  return double.tryParse(value.toString()) ?? defaultValue;
}

Size? _tryParseSize(dynamic value, [Size? defaultValue]) {
  if (value == null) {
    return defaultValue;
  }
  if (value is Size) {
    return value;
  }
  final split = value.toString().split('x');
  return Size(
    _tryParseDouble(split.first)!,
    _tryParseDouble(split.last)!,
  );
}

Duration? _tryParseDuration(dynamic value, [Duration? defaultValue]) {
  if (value == null) {
    return defaultValue;
  }
  if (value is Duration) {
    return value;
  }
  return Duration(
    milliseconds: (_tryParseDouble(value, 0)! * 1000).toInt(),
  );
}

Map<String, String?>? _convertAttributeMap(String? attributeValue) {
  if (attributeValue?.isNotEmpty != true) {
    return null;
  }
  final split = attributeValue!.split(RegExp(',( *)'));
  final entries = split.map((e) {
    final keyValues = e.split('=');
    var value = keyValues.last;
    if (RegExp('".*?"').hasMatch(value)) {
      value = value.substring(1, value.length - 1);
    }
    return MapEntry(keyValues.first, value);
  });
  return Map.fromEntries(entries);
}

/// aes解密
Uint8List decrypt(Uint8List data, Uint8List? keyData, String? ivStr) {
  if (keyData == null) {
    return data;
  }
  if (ivStr?.startsWith('0x') == true) {
    ivStr = int.tryParse(ivStr!, radix: 16).toString();
  }
  IV iv;
  if (ivStr?.length != 16) {
    iv = IV.fromLength(16);
  } else {
    iv = IV(Uint8List.fromList(ivStr!.codeUnits));
  }
  final decryptBytes = Encrypter(AES(
    Key(keyData),
    mode: AESMode.cbc,
  )).decryptBytes(
    Encrypted(data),
    iv: iv,
  );
  return Uint8List.fromList(decryptBytes);
}

// 拼接url
String _mergeUrl(String url, String currentPath) {
  var current = currentPath;
  if (!current.startsWith(_httpHeaderRegExp)) {
    final indexUri = Uri.parse(url);
    final pathSegments = List.of(indexUri.pathSegments);
    pathSegments.remove(path.basename(url));
    final currentPaths = path.split(current);
    for (var currentPath in currentPaths) {
      if (!pathSegments.contains(currentPath)) {
        pathSegments.add(currentPath);
      }
    }
    final replacedUri = indexUri.replace(
      pathSegments: pathSegments,
    );
    current = replacedUri.toString();
  }
  return current;
}
