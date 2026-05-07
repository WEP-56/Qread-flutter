import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/routes.dart';
import '../models/rss_source.dart';
import '../pages/rss/rss_article_list_page.dart';

enum RssSourceCardDisplayMode {
  grid,
  list,
}

class RssSourceCard extends StatelessWidget {
  final RssSource source;
  final RssSourceCardDisplayMode displayMode;

  const RssSourceCard({
    Key? key,
    required this.source,
    this.displayMode = RssSourceCardDisplayMode.grid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return displayMode == RssSourceCardDisplayMode.grid
        ? _buildGridCard(context)
        : _buildListCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        _accentFromSeed(source.sourceName ?? source.sourceGroup ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSource(context),
        child: Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.08),
              theme.cardColor,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIcon(context, size: 70, radius: 18),
              const SizedBox(height: 14),
              Text(
                source.sourceName ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openSource(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildIcon(context, size: 40, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.sourceName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.sourceComment ?? source.sourceUrl ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context, {
    required double size,
    required double radius,
  }) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.rss_feed_rounded,
        size: size * 0.46,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (source.sourceIcon == null || source.sourceIcon!.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: source.sourceIcon!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  void _openSource(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.rssArticles,
      arguments: RssArticleListPageArgs(source: source),
    );
  }

  Color _accentFromSeed(String seed) {
    const palette = [
      Color(0xFFE85D3F),
      Color(0xFF4B8BFF),
      Color(0xFF35A97A),
      Color(0xFFF0A53A),
      Color(0xFF8B63F6),
      Color(0xFFE05C92),
    ];
    if (seed.isEmpty) {
      return palette.first;
    }
    return palette[seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
        palette.length];
  }
}
