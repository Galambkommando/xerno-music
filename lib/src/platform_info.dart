import 'dart:io';

import 'package:flutter/foundation.dart';

bool get isLinuxDesktop => !kIsWeb && Platform.isLinux;

bool get isAndroidDevice => !kIsWeb && Platform.isAndroid;
