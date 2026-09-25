import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../api/models.dart';

class MediaTile extends StatelessWidget {
  final DirEntry entry;
  final String? thumbnailUrl;
  final Map<String, String> headers;
  final VoidCallback onTap;

  const MediaTile({
    super.key,
    required this.entry,
    this.thumbnailUrl,
    this.headers = const {},
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
        httpHeaders: headers,
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

/// Square cell for the grid view: the thumbnail and nothing else for
/// media; an icon plus name for folders and unplayable files.
class MediaGridTile extends StatelessWidget {
  final DirEntry entry;
  final String? thumbnailUrl;
  final Map<String, String> headers;
  final VoidCallback onTap;

  const MediaGridTile({
    super.key,
    required this.entry,
    this.thumbnailUrl,
    this.headers = const {},
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    if (thumbnailUrl != null) {
      child = CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        httpHeaders: headers,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade600,
          child: Container(color: Colors.grey),
        ),
        // Audio without cover art, or a file ffmpeg can't read: fall back
        // to the type icon rather than a broken-image glyph.
        errorWidget: (context, url, error) => _IconCell(entry: entry, scheme: scheme),
      );
    } else {
      child = _IconCell(entry: entry, scheme: scheme);
    }
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(message: entry.name, child: child),
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  final DirEntry entry;
  final ColorScheme scheme;
  const _IconCell({required this.entry, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.type) {
      'folder' => Icons.folder,
      'video' => Icons.movie,
      'audio' => Icons.music_note,
      'photo' => Icons.image,
      _ => Icons.insert_drive_file,
    };
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
