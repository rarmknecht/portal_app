import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PhotoViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const PhotoViewerScreen({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: PhotoView(
        imageProvider: NetworkImage(url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        loadingBuilder: (_, event) => Center(
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
          ),
        ),
        errorBuilder: (context, error, stack) => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.broken_image, size: 64, color: Colors.white54),
            SizedBox(height: 12),
            Text('Could not load image', style: TextStyle(color: Colors.white54)),
          ]),
        ),
      ),
    );
  }
}
