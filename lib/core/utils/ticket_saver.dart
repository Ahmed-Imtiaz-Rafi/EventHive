import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/rendering.dart';

/// Turns what [boundary] draws into a PNG picture and saves it.
///
/// On the web the picture is downloaded; on a phone it is saved as a
/// file in the downloads location. To save into the photo gallery
/// instead, replace the `saveFile` call with a gallery package such as
/// `gal`; nothing else needs to change.
Future<void> saveTicketImage(
  RenderRepaintBoundary boundary, {
  required String fileName,
}) async {
  // pixelRatio 3 gives a sharp picture.
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw Exception('Could not create the ticket picture');
  }

  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: data.buffer.asUint8List(),
    fileExtension: 'png',
    mimeType: MimeType.png,
  );
}