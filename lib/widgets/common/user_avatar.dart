import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/avatar_url.dart';
import 'package:flutter/material.dart';

/// Round profile picture. Shows the image when there is one; otherwise
/// (or if the image fails to load) a navy circle with a person icon.
///
/// [path] is what `users.avatar_url` holds: a path inside the `avatars`
/// bucket. The address is built here, see [avatarPublicUrl].
class UserAvatar extends StatelessWidget {
  final String? path;
  final double size;

  const UserAvatar({super.key, required this.path, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final url = avatarPublicUrl(path);

    final fallback = ColoredBox(
      color: kNavy,
      child: Icon(Icons.person_outline, color: Colors.white, size: size * 0.5),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : Image.network(
                url,
                // cover = fill the circle, centered.
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}