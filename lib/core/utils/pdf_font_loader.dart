import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFontLoader {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static const _regularUrl =
      'https://fonts.gstatic.com/s/notosans/v36/o-0mIpQlx3QUlC5A4PNB6Ryti20_6n1iPHjcz6L1SoM-jCpoiyD9A-9a6Vc.ttf';
  static const _boldUrl =
      'https://fonts.gstatic.com/s/notosans/v36/o-0mIpQlx3QUlC5A4PNB6Ryti20_6n1iPHjcz6L1SoM-jCpoiyAUBu9a6Vc.ttf';

  static Future<pw.Font> regular() async {
    _regular ??= pw.Font.ttf(await _loadFont('NotoSans-Regular', _regularUrl));
    return _regular!;
  }

  static Future<pw.Font> bold() async {
    _bold ??= pw.Font.ttf(await _loadFont('NotoSans-Bold', _boldUrl));
    return _bold!;
  }

  static Future<ByteData> _loadFont(String name, String url) async {
    // Try cache first
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name.ttf');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return ByteData.sublistView(bytes);
      }
    } catch (_) {}

    // Download
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      // Cache for next time
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name.ttf');
        await file.writeAsBytes(response.bodyBytes);
      } catch (_) {}
      return ByteData.sublistView(response.bodyBytes);
    }

    throw Exception('Failed to load font $name');
  }

  /// Fallback fonts that work without network (no Polish chars)
  static pw.Font get fallbackRegular => pw.Font.helvetica();
  static pw.Font get fallbackBold => pw.Font.helveticaBold();

  /// Load with fallback — never throws
  static Future<(pw.Font, pw.Font)> loadWithFallback() async {
    try {
      return (await regular(), await bold());
    } catch (_) {
      return (fallbackRegular, fallbackBold);
    }
  }
}
