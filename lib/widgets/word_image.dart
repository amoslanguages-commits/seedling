import 'package:flutter/material.dart';

/// A widget that displays a word illustration image from assets.
///
/// Images are stored at: `assets/images/words/{imageId}.jpg`
/// e.g. `assets/images/words/Img_42.jpg`
///
/// Gracefully shows nothing if [imageId] is null or the image is missing.
class WordImage extends StatelessWidget {
  final String? imageId;
  final double size;
  final BorderRadius? borderRadius;

  const WordImage({
    super.key,
    required this.imageId,
    this.size = 140,
    this.borderRadius,
  });

  /// Asset path for a given imageId
  static String? assetPath(String? imageId) {
    if (imageId == null || imageId.isEmpty) return null;
    return 'assets/images/words/$imageId.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final path = WordImage.assetPath(imageId);
    if (path == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
