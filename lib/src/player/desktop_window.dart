import 'package:flutter/services.dart';

import '../constants.dart';
import '../platform_info.dart';

class DesktopWindow {
  static const MethodChannel _channel = MethodChannel(kWindowChannel);

  static Future<void> setMini(bool mini) async {
    if (!isLinuxDesktop) return;
    try {
      await _channel.invokeMethod<void>('setAlwaysOnTop', mini);
      await _channel.invokeMethod<void>('resize', {
        'width': mini ? 440 : 1280,
        'height': mini ? 176 : 840,
      });
    } catch (_) {}
  }

  static Future<void> present() async {
    if (!isLinuxDesktop) return;
    try {
      await _channel.invokeMethod<void>('present');
    } catch (_) {}
  }
}
