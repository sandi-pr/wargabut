import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PhotoViewer extends StatelessWidget {
  final String url;
  const PhotoViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PhotoView(
        imageProvider: CachedNetworkImageProvider(url),
      ),
    );
  }
}
