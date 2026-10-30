import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Round profile picture. Shows the image when there is one; otherwise
/// (or if the image fails to load) a navy circle with a person icon.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const UserAvatar({super.key, required this.imageUrl, this.size = 56});

  @override
  Widget build(BuildContext context) {
    // A blank link counts as "no picture", the same as null.
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    final fallback = ColoredBox(
      color: kNavy,
      child: Icon(Icons.person_outline, color: Colors.white, size: size * 0.5),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.network(
                url,
                // cover = fill the circle, centered.
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}