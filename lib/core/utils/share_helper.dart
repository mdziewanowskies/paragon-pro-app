import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareFiles(
  BuildContext context,
  List<XFile> files, {
  String? subject,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 200, 200);

  await Share.shareXFiles(
    files,
    subject: subject,
    sharePositionOrigin: origin,
  );
}
