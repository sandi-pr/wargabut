import 'package:flutter/material.dart';

class SharedFilterSegments extends StatelessWidget {
  final bool isFilter1Selected;
  final bool isFilter2Selected;
  final Function(Set<String> selectedValues) onSelectionChanged;

  // Parameter kustomisasi (Default ke Lokasi & Bulan agar aman untuk Event/Konser)
  final String filter1Label;
  final String filter1Value;
  final IconData filter1Icon;

  final String filter2Label;
  final String filter2Value;
  final IconData filter2Icon;

  const SharedFilterSegments({
    super.key,
    required this.isFilter1Selected,
    required this.isFilter2Selected,
    required this.onSelectionChanged,
    this.filter1Label = 'Lokasi',
    this.filter1Value = 'Lokasi',
    this.filter1Icon = Icons.location_on,
    this.filter2Label = 'Bulan',
    this.filter2Value = 'Bulan',
    this.filter2Icon = Icons.calendar_month,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<String>(
        emptySelectionAllowed: true,
        multiSelectionEnabled: true,
        selected: <String>{
          if (isFilter1Selected) filter1Value,
          if (isFilter2Selected) filter2Value,
        },
        onSelectionChanged: onSelectionChanged,
        segments: [
          ButtonSegment(
            value: filter1Value,
            label: Text(filter1Label),
            icon: Icon(filter1Icon),
          ),
          ButtonSegment(
            value: filter2Value,
            label: Text(filter2Label),
            icon: Icon(filter2Icon),
          ),
        ],
      ),
    );
  }
}