import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.profile,
    this.imageUrl,
    this.size = 72,
    this.imageKey,
  });

  final UserProfile? profile;
  final String? imageUrl;
  final double size;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl ?? profile?.avatarImageUrl;
    final image = _buildImage(source);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: .78), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image ??
          Icon(
            Icons.person_rounded,
            size: size * .48,
            color: AppColors.primaryDark,
          ),
    );
  }

  Widget? _buildImage(String? source) {
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image/')) {
      return Image.memory(
        base64Decode(source.split(',').last),
        key: imageKey,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    if (source.startsWith('https://')) {
      return Image.network(
        source,
        key: imageKey,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return null;
  }
}
