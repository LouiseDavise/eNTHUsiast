import 'package:flutter/material.dart';

class CustomImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final String? semanticLabel;

  const CustomImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the URL is a web address or a local asset path
    final isNetworkImage = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        // Shows a progress indicator while the image is downloading
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[400],
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
              ),
            ),
          );
        },
        // Shows an error icon if the link is broken
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: Colors.grey,
                size: 32,
              ),
            ),
          );
        },
      );
    } else {
      // Fallback for local assets (e.g., 'assets/images/profile.png')
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: Colors.grey,
                size: 32,
              ),
            ),
          );
        },
      );
    }
  }
}