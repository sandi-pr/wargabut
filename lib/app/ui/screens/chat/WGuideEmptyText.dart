import 'package:flutter/material.dart';

class WGuideEmptyText extends StatelessWidget {
  const WGuideEmptyText({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bullets = <String>[
      'Event jejepangan di Jakarta weekend ini',
      'Etika cosplay & foto di event Jejepangan',
      'Tips cosplay untuk pemula',
      'Makeup cosplay tahan keringat & panas',
      'Trik hemat: sewa kostum/props cosplay',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WGuide',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Panduan singkat jadwal & tips event jejepangan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(.75),
                ),
              ),
              const SizedBox(height: 12),
              Text('Contoh pertanyaan:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                bullets.map((e) => '• $e').join('\n'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Tulis pertanyaanmu di kolom chat di bawah.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
