import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ListTileEvent extends StatelessWidget {
  final String eventName;
  final String eventDate;
  final String location;
  const ListTileEvent({
    super.key,
    required this.eventName,
    required this.eventDate,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: TemplateCard(
        eventName: eventName,
        eventDate: eventDate,
        location: location,
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final String eventName;
  final String eventDate;
  final String location;
  const TemplateCard({
    super.key,
    required this.eventName,
    required this.eventDate,
    required this.location,
  });

  String createPlaceholderAvatar(String organizer) {
    List<String> words = organizer.split(' ');
    List<String> initials = words.map((word) => word[0]).toList();

    initials = initials.sublist(0, 2);

    return initials.join('');
  }

  @override
  Widget build(BuildContext context) {
    // String placeholderAvatar = createPlaceholderAvatar(organizer);
    // const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                eventDate,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Text(
              //   htm,
              //   style: TextStyle(
              //     color: Theme.of(context).colorScheme.primary,
              //     fontSize: 14.0,
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
            ],
          ),
          Text(
            eventName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 22.0,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: AutoSizeText(
                  location,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
