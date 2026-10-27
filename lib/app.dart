import 'package:flutter/material.dart';

import 'src/constants.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/shell.dart';

class XernoApp extends StatelessWidget {
  const XernoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const XernoShell(),
    );
  }
}
