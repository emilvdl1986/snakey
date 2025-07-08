import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareCurrentScreen(BuildContext context, ScreenshotController controller) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not supported on web.')),
      );
      return;
    }
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not supported on this platform.')),
      );
      return;
    }
    try {
      final Uint8List? image = await controller.capture();
      if (image == null) return;
      final tempDir = await Directory.systemTemp.createTemp();
      final file = await File('${tempDir.path}/screenshot.png').writeAsBytes(image);
      await Share.shareXFiles([XFile(file.path)], text: 'Check out my Snake game!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share screenshot: $e')),
      );
    }
  }
}
