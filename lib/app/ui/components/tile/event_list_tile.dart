import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/provider/transit_provider.dart';
// Import Shared Card
import '../shared/shared_event_card.dart';

class EventListTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const EventListTile({super.key, required this.data});

  @override
  State<EventListTile> createState() => _EventListTileState();
}

class _EventListTileState extends State<EventListTile> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isAdmin = prefs.getBool('isAdmin') ?? false;
      });
    }
  }

  void _navigateToDetail() {
    final String eventId = widget.data['id'];
    context.read<TransitProvider>().clearRoutes();
    // Navigasi khusus Event
    context.go('/jeventku/$eventId', extra: widget.data);
  }

  @override
  Widget build(BuildContext context) {
    return SharedEventCard(
      data: widget.data,
      isAdmin: _isAdmin,
      storageBucket: 'jfestchart', // Bucket khusus Event
      onTap: _navigateToDetail,
    );
  }
}