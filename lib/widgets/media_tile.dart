import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../api/models.dart';

class MediaTile extends StatelessWidget {
  final DirEntry entry;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  const MediaTile({
    super.key,
    required this.entry,
    this.thumbnailUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _thumbnail(context),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(), style: Theme.of(context).textTheme.bodySmall),
      trailing: _badge(context),
      onTap: onTap,
    );
  }

  Widget _thumbnail(BuildContext context) {
    if (entry.isFolder) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Icon(Icons.folder, size: 40),
      );
    }
    if (thumbnailUrl == null) {
      return const SizedBox(width: 56, height: 56, child: Icon(Icons.image, size: 40));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade600,
          child: Container(width: 56, height: 56, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      ),
    );
  }

  Widget _badge(BuildContext context) {
    final color = switch (entry.type) {
      'video' => Colors.blue,
      'audio' => Colors.green,
      'photo' => Colors.orange,
      _ => Colors.grey,
    };
    if (entry.isFolder) return const Icon(Icons.chevron_right);
    return Chip(
      label: Text(entry.type, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }

  String _subtitle() {
    if (entry.isFolder) return '';
    if (entry.size != null) {
      final mb = entry.size! / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '';
  }
}
