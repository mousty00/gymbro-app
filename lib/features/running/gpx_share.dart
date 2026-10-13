import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/ui.dart';

/// Scarica il GPX dal backend e lo passa al foglio di condivisione del sistema
/// (Strava, Garmin, Komoot, File…).
Future<void> shareGpx(BuildContext context, Future<String> Function() load, String fileName) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final gpx = await load();
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(gpx), mimeType: 'application/gpx+xml')],
      fileNameOverrides: ['$fileName.gpx'],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
  }
}

/// Nome file leggibile: "Giro del parco" → "giro-del-parco".
String gpxFileName(String name) {
  final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'repbirds' : slug;
}
