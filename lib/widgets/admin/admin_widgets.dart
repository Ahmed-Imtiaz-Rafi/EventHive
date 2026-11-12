import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Shared building blocks for the admin oversight screens.
// Lives in lib/widgets/admin/admin_widgets.dart

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 12 Nov 2026
String adminDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String adminMonth(DateTime d) => _months[d.month - 1].toUpperCase();

/// "14:30:00" -> "2:30 PM"
String adminTime(String? hhmmss) {
  if (hhmmss == null || hhmmss.length < 4) return '';
  final parts = hhmmss.split(':');
  final h = int.tryParse(parts[0]);
  final min = parts.length > 1 ? parts[1] : '00';
  if (h == null) return hhmmss;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$min ${h >= 12 ? 'PM' : 'AM'}';
}

/// "3 d ago", falls back to a date after a month.
String adminAgo(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  return adminDate(t.toLocal());
}

/// full_name, falling back to username.
String adminName(Map? u) {
  final full = (u?['full_name'] ?? '').toString().trim();
  if (full.isNotEmpty) return full;
  final un = (u?['username'] ?? '').toString();
  return un.isEmpty ? 'Unknown user' : un;
}

/// Turns "PROOF_REQUIRED: the applicant has not uploaded proof" into
/// "the applicant has not uploaded proof".
String adminError(Object e) {
  var m = e is PostgrestException ? e.message : e.toString();
  final i = m.indexOf(': ');
  if (i > 0 && RegExp(r'^[A-Z_]+$').hasMatch(m.substring(0, i))) {
    m = m.substring(i + 2);
  }
  return m;
}

/// Back arrow, page title and a one-line subtitle.
class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AdminHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_rounded, color: c.ink),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin/home');
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: c.ink,
                  ),
                ),
                Text(subtitle, style: t.bodySmall?.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Underline tab bar. Must sit under a DefaultTabController.
class AdminTabBar extends StatelessWidget {
  final List<String> labels;
  const AdminTabBar({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    return TabBar(
      tabs: [for (final l in labels) Tab(text: l)],
      labelColor: c.brand,
      unselectedLabelColor: c.muted,
      indicatorColor: c.brand,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: c.border,
      labelStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: t.labelLarge,
    );
  }
}

class AdminSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.muted),
        prefixIcon: Icon(Icons.search_rounded, color: c.muted),
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.brand),
      ),
    );
  }
}

/// Tappable (optional) bordered surface, the base of every list row.
class AdminCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const AdminCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum AdminTone { neutral, attention, success, danger }

/// Small rounded status / tag label.
class AdminPill extends StatelessWidget {
  final String label;
  final AdminTone tone;
  const AdminPill({
    super.key,
    required this.label,
    this.tone = AdminTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color fg;
    final Color bg;
    switch (tone) {
      case AdminTone.neutral:
        fg = c.brand;
        bg = c.brandSoft;
      case AdminTone.attention:
        fg = c.accent;
        bg = c.accentSoft;
      case AdminTone.success:
        fg = dark ? const Color(0xFF6FCF97) : const Color(0xFF1E7A4C);
        bg = fg.withValues(alpha: 0.14);
      case AdminTone.danger:
        fg = Theme.of(context).colorScheme.error;
        bg = fg.withValues(alpha: 0.12);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Round profile picture (public 'avatars' bucket) with an initials fallback.
class AdminAvatar extends StatelessWidget {
  final String? path;
  final String name;
  final double size;
  const AdminAvatar({
    super.key,
    required this.path,
    required this.name,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final p = path;
    final url = (p == null || p.isEmpty)
        ? null
        : Supabase.instance.client.storage.from('avatars').getPublicUrl(p);
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: c.brand,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

/// Centered icon + message with an optional action (empty and error states).
class AdminMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AdminMessage({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: c.muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pull-to-refresh list with an empty state. Used inside every tab.
class AdminRefreshList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyText;
  final IconData emptyIcon;
  const AdminRefreshList({
    super.key,
    required this.onRefresh,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyText,
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: itemCount == 0
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                AdminMessage(icon: emptyIcon, text: emptyText),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: itemBuilder,
            ),
    );
  }
}
