import 'package:flutter/material.dart';

class SharedFilterSegments extends StatelessWidget {
  final bool isLocationSelected;
  final bool isMonthSelected;
  // Callback ini mengembalikan Set<String> berisi filter yang aktif
  final Function(Set<String> selectedValues) onSelectionChanged;

  const SharedFilterSegments({
    super.key,
    required this.isLocationSelected,
    required this.isMonthSelected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<String>(
        emptySelectionAllowed: true,
        multiSelectionEnabled: true,
        selected: <String>{
          if (isLocationSelected) 'Lokasi',
          if (isMonthSelected) 'Bulan',
        },
        onSelectionChanged: onSelectionChanged,
        segments: const [
          ButtonSegment(
              value: 'Lokasi',
              label: Text('Lokasi'),
              icon: Icon(Icons.location_on)
          ),
          ButtonSegment(
              value: 'Bulan',
              label: Text('Bulan'),
              icon: Icon(Icons.calendar_month)
          ),
        ],
      ),
    );
  }
}