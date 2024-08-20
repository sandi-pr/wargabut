
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EventCard extends StatelessWidget {
  final String eventName;
  final String eventPoster;
  final String eventDate;
  final String socialMedia;
  final String organizer;
  final String location;
  final String htm;
  const EventCard({
    super.key,
    required this.eventName,
    required this.eventPoster,
    required this.eventDate,
    required this.socialMedia,
    required this.organizer,
    required this.location,
    required this.htm,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: TemplateCard(
        eventName: eventName,
        eventPoster: eventPoster,
        eventDate: eventDate,
        socialMedia: socialMedia,
        organizer: organizer,
        location: location,
        htm: htm,
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final String eventName;
  final String eventPoster;
  final String eventDate;
  final String socialMedia;
  final String organizer;
  final String location;
  final String htm;
  const TemplateCard({
    super.key,
    required this.eventName,
    required this.eventPoster,
    required this.eventDate,
    required this.socialMedia,
    required this.organizer,
    required this.location,
    required this.htm,
  });

  String createPlaceholderAvatar(String organizer) {
    List<String> words = organizer.split(' ');
    List<String> initials = words.map((word) => word[0]).toList();

    initials = initials.sublist(0, 2);

    return initials.join('');
  }

  @override
  Widget build(BuildContext context) {
    String placeholderAvatar = createPlaceholderAvatar(organizer);
    const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  placeholderAvatar,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organizer,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      socialMedia,
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
        if (kIsWeb)
          Image.network(eventPoster),
        if (!kIsWeb)
        CachedNetworkImage(
          imageUrl: eventPoster,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
        // Image.network(eventPoster),
        // Image(image: CachedNetworkImageProvider(eventPoster)),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    eventDate,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    htm,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                eventName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 22.0,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                location,
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
