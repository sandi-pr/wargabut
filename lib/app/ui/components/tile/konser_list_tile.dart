import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import Shared Card
import '../shared/shared_event_card.dart';

class KonserListTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const KonserListTile({super.key, required this.data});

  @override
  State<KonserListTile> createState() => _KonserListTileState();
}

class _KonserListTileState extends State<KonserListTile> {
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
    // Navigasi khusus Konser
    context.go('/dkonser/$eventId', extra: widget.data);
  }

  @override
  Widget build(BuildContext context) {
    return SharedEventCard(
      data: widget.data,
      isAdmin: _isAdmin,
      storageBucket: 'dfestkonser', // Bucket khusus Konser
      onTap: _navigateToDetail,
    );
  }
}