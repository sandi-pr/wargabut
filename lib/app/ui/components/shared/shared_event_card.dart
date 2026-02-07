import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:wargabut/app/services/firebase_storage.dart';

// Callback saat user tap kartu (untuk navigasi)
typedef OnCardTap = void Function();

class SharedEventCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  final String storageBucket; // 'jfestchart' atau 'dkonser'
  final OnCardTap? onTap;

  const SharedEventCard({
    super.key,
    required this.data,
    required this.isAdmin,
    required this.storageBucket,
    this.onTap,
  });

  @override
  State<SharedEventCard> createState() => _SharedEventCardState();
}

class _SharedEventCardState extends State<SharedEventCard> {
  bool isExpanded = false;

  void toggleLayout() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMedpart = widget.data['is_medpart'] ?? false;

    // 1. KONTEN UTAMA KARTU
    Widget content = _CardBody(
      data: widget.data,
      isAdmin: widget.isAdmin,
      storageBucket: widget.storageBucket,
      isExpanded: isExpanded,
      onToggleLayout: toggleLayout,
      onTapContent: widget.onTap,
    );

    // 2. BUNGKUS DENGAN CARD (Material)
    Widget card = Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        // Jika tidak ada poster/admin, mungkin tap tidak melakukan apa-apa?
        // Tapi biasanya user expect tap di mana saja.
        // Biarkan child (_CardBody) menangani tap spesifik jika perlu,
        // atau biarkan InkWell ini menangani tap global.
        // Di sini kita biarkan null agar gesture detector di dalam _CardBody yang bekerja
        // atau kita bisa pasang widget.onTap di sini jika ingin simple.
        onTap: null,
        child: content,
      ),
    );

    // 3. LOGIKA BANNER MEDPART
    if (isMedpart) {
      return Card.outlined(
        clipBehavior: Clip.hardEdge,
        child: Banner(
          color: Theme.of(context).colorScheme.primaryContainer,
          shadow: const BoxShadow(color: Colors.transparent),
          textStyle: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          message: "Medpart",
          location: BannerLocation.topEnd,
          child: InkWell(child: content),
        ),
      );
    }

    return card;
  }
}

// --- PRIVATE WIDGET: BODY UTAMA (MENGATUR ROW/COLUMN) ---
class _CardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  final String storageBucket;
  final bool isExpanded;
  final VoidCallback onToggleLayout;
  final OnCardTap? onTapContent;

  const _CardBody({
    required this.data,
    required this.isAdmin,
    required this.storageBucket,
    required this.isExpanded,
    required this.onToggleLayout,
    this.onTapContent,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPoster = data['is_postered'] == true;
    final bool canNavigate = hasPoster || isAdmin;

    // Bagian Gambar
    Widget imageSection = hasPoster
        ? _EventPosterImage(
      data: data,
      storageBucket: storageBucket,
      isExpanded: isExpanded,
      onTap: onToggleLayout,
    )
        : const SizedBox();

    // Bagian Teks
    Widget textSection = GestureDetector(
      onTap: canNavigate ? onTapContent : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _EventContentText(data: data),
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isExpanded
          ? Column(
        key: const ValueKey("columnLayout"),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [imageSection, textSection],
      )
          : Row(
        key: const ValueKey("rowLayout"),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [imageSection, Expanded(child: textSection)],
      ),
    );
  }
}

// --- PRIVATE WIDGET: GAMBAR POSTER ---
class _EventPosterImage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String storageBucket;
  final bool isExpanded;
  final VoidCallback onTap;

  const _EventPosterImage({
    required this.data,
    required this.storageBucket,
    required this.isExpanded,
    required this.onTap,
  });

  Future<String?> _getPosterUrl() async {
    // 1. Cek Array Posters
    if (data['posters'] != null) {
      List<dynamic> posters = data['posters'];
      var mainPoster = posters.firstWhere(
            (poster) => poster['is_main'] == true,
        orElse: () => null,
      );
      if (mainPoster != null && mainPoster['url'] != null) {
        return mainPoster['url'];
      }
    }
    // 2. Fallback ke Storage Service
    final StorageService storageService = StorageService();
    return storageService.getImageUrl(storageBucket, data['event_name']);
  }

  @override
  Widget build(BuildContext context) {
    final double? width = isExpanded ? MediaQuery.of(context).size.width : 120;
    final double? height = isExpanded ? null : 140;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: "${data['event_name']}${data['date'] ?? ''}",
        child: SizedBox(
          width: width,
          height: height,
          child: FutureBuilder<String?>(
            future: _getPosterUrl(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasData && snapshot.data != null) {
                return Image.network(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                );
              } else {
                return const SizedBox();
              }
            },
          ),
        ),
      ),
    );
  }
}

// --- PRIVATE WIDGET: TEKS KONTEN ---
class _EventContentText extends StatelessWidget {
  final Map<String, dynamic> data;

  const _EventContentText({required this.data});

  @override
  Widget build(BuildContext context) {
    final bool hasPoster = data['is_postered'] == true;
    final String eventName = (data['event_name'] ?? '').replaceAll('\\n', '\n');
    final String? date = data['date'];
    final String location = data['location'] ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          eventName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: hasPoster ? 18.0 : 22.0,
            fontWeight: FontWeight.w400,
          ),
          softWrap: true,
          maxLines: 2,
        ),
        const SizedBox(height: 8.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (date != null && date.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 8.0),
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
    );
  }
}