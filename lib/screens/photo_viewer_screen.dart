import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../api/models.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<DirEntry> siblings;
  final int initialIndex;
  final String Function(String path) streamUrlBuilder;

  const PhotoViewerScreen({
    super.key,
    required this.siblings,
    required this.initialIndex,
    required this.streamUrlBuilder,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  // Only photo-type siblings are navigable here.
  late final List<DirEntry> _photos;

  @override
  void initState() {
    super.initState();
    _photos = widget.siblings.where((e) => e.type == 'photo').toList();
    // Map the original index (into siblings) into the photos-only list.
    final originalItem = widget.siblings[widget.initialIndex];
    _currentIndex = _photos.indexWhere((e) => e.path == originalItem.path);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text(
          _photos.isNotEmpty ? _photos[_currentIndex].name : '',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_photos.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${_photos.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _photos.isEmpty
          ? const Center(child: Text('No photos', style: TextStyle(color: Colors.white)))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) {
                final url = widget.streamUrlBuilder(_photos[i].path);
                return PhotoView(
                  key: ValueKey(url),
                  imageProvider: NetworkImage(url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  loadingBuilder: (_, event) => Center(
                    child: CircularProgressIndicator(
                      value: event?.expectedTotalBytes != null
                          ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  ),
                  errorBuilder: (context, error, stack) => const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.white38),
                      SizedBox(height: 12),
                      Text('Could not load image',
                          style: TextStyle(color: Colors.white54)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
