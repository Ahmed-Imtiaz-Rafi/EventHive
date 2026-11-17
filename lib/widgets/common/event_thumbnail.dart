import 'package:flutter/material.dart';

/// Small rounded square showing an event's image, or a plain colored
/// square when the event has no image or the image fails to load.
class EventThumbnail extends StatelessWidget {
  final String? imageUrl;

  /// Color shown when there is no image.
  final Color fallback;
  final double size;

  const EventThumbnail({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    // A blank link counts as "no image", the same as null.
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.network(
                url,
                // cover = fill the square, centered.
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : ColoredBox(color: fallback),
                errorBuilder: (_, _, _) => ColoredBox(color: fallback),
              )
            : ColoredBox(color: fallback),
      ),
    );
  }
}