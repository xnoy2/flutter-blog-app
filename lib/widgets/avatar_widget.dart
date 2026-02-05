import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? displayName;
  final double size;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.displayName,
    this.size = 40,
  });

  String _initial() {
    if (displayName == null || displayName!.isEmpty) return '?';
    return displayName![0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      key: ValueKey(imageUrl), // FORCE rebuild when URL changes
      radius: size / 2,
      backgroundColor: Colors.grey.shade300,
      backgroundImage:
          imageUrl != null && imageUrl!.isNotEmpty
              ? NetworkImage(imageUrl!)
              : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              _initial(),
              style: TextStyle(
                fontSize: size / 2,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            )
          : null,
    );
  }
}
