import 'package:flutter/material.dart';

import '../core/auth/app_user.dart';

/// Parses a `#RRGGBB` avatar_color string into a [Color]; falls back to
/// emerald if malformed so a bad row never crashes a screen.
Color memberColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null || cleaned.length != 6) return const Color(0xFF23907F);
  return Color(0xFF000000 | value);
}

/// Coloured initial avatar used across calendar, chat, GPS, and dashboards
/// — one member, one colour, everywhere (docs/04-design-system.md).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.user, this.radius = 18});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: memberColor(user.avatarColor),
      foregroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
      child: Text(
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        style: TextStyle(color: Colors.white, fontSize: radius * 0.9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
