
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wargabut/app/ui/screens/impactnation/detail/poster_detail.dart';

class PosterCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<String> posterUrls;
  final String urlAvatar;
  const PosterCard({
    super.key,
    required this.data,
    required this.posterUrls,
    required this.urlAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Card.outlined(
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  data: data,
                  posterUrls: posterUrls,
                ),
              ),
            );
          },
          child: TemplateCard(
            data: data,
            posterUrls: posterUrls,
            urlAvatar: urlAvatar,
          ),
        ),
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<String> posterUrls;
  final String urlAvatar;
  const TemplateCard({
    super.key,
    required this.data,
    required this.posterUrls,
    required this.urlAvatar,
  });

  String createPlaceholderAvatar(String organizer) {
    if (organizer.contains('_')) {
      List<String> parts = organizer.split('_');
      if (parts.length > 1) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        return organizer.substring(0, 2).toUpperCase();
      }
    }

    List<String> words = organizer.split(' ');
    List<String> initials = [];

    if (words.isNotEmpty) {
      initials.add(words[0][0]);
    }

    if (words.length > 1) {
      initials.add(words[1][0]);
    }

    return initials.join('').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    String placeholderAvatar = createPlaceholderAvatar(data['organizer']);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: urlAvatar != "" ? NetworkImage(urlAvatar) : null,
                child: urlAvatar == ""
                    ? Text(
                        placeholderAvatar,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['social_media'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      data['organizer'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        CachedNetworkImage(
          imageUrl: posterUrls[0],
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['date'],
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                data['title'],
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 22.0,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                data['location'],
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
