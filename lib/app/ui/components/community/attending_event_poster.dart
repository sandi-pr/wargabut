import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/event_provider.dart';

/// Widget thumbnail poster untuk event yang akan dihadiri.
/// Secara otomatis mengambil poster terbaru dari EventProvider / Firestore
/// sehingga poster selalu terupdate jika panitia/admin memperbarui poster event.
class AttendingEventPoster extends StatefulWidget {
  final String eventId;
  final String initialPosterUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const AttendingEventPoster({
    super.key,
    required this.eventId,
    this.initialPosterUrl = '',
    this.width = 44,
    this.height = 56,
    this.borderRadius,
  });

  @override
  State<AttendingEventPoster> createState() => _AttendingEventPosterState();
}

class _AttendingEventPosterState extends State<AttendingEventPoster> {
  @override
  void initState() {
    super.initState();
    _checkLatestPoster();
  }

  @override
  void didUpdateWidget(covariant AttendingEventPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _checkLatestPoster();
    }
  }

  void _checkLatestPoster() {
    if (widget.eventId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventProvider>().fetchLatestPosterUrl(widget.eventId);
    });
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    final radius = widget.borderRadius ?? BorderRadius.circular(6);
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: radius,
      ),
      child: Icon(
        Icons.event,
        color: colorScheme.primary,
        size: widget.width > 30 ? 24 : 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ep = context.watch<EventProvider>();
    final posterUrl = ep.getLatestPosterUrl(
      widget.eventId,
      fallback: widget.initialPosterUrl,
    );
    final radius = widget.borderRadius ?? BorderRadius.circular(6);

    if (posterUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          posterUrl,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
        ),
      );
    }

    return _buildPlaceholder(colorScheme);
  }
}
