import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/rss_source.dart';
import '../../services/api_service.dart';

class RssSourceCard extends StatelessWidget {
  final RssSource source;

  const RssSourceCard({Key? key, required this.source}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // TODO: 打开RSS文章列表
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: source.sourceIcon != null && source.sourceIcon!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: source.sourceIcon!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.rss_feed, size: 24),
                        ),
                      )
                    : const Icon(Icons.rss_feed, size: 24),
              ),
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
}
