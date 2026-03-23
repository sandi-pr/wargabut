import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../../provider/theme_provider.dart';
import 'shared_sponsor_section.dart';
import 'list_page_config.dart';

class SharedWelcomeView<T> extends StatelessWidget {
  final ListPageConfig config;
  final List<T> upcomingEvents;
  final Widget Function(BuildContext, T) itemBuilder;
  final VoidCallback onSeeAllUpcoming;
  late bool? isSponsorView;

  SharedWelcomeView({
    super.key,
    required this.config,
    required this.upcomingEvents,
    required this.itemBuilder,
    required this.onSeeAllUpcoming,
    this.isSponsorView,
  });

  @override
  Widget build(BuildContext context) {

    final themeProvider = context.watch<ThemeProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        children: [
          // --- BANNER MASCOT ---
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Image(
                      // width: 150,
                      image: AssetImage(themeProvider.isDark ? config.bannerMenuPageDark : config.bannerMenuPage),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image(
                        width: 150,
                        image: AssetImage(config.mascotAsset),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 130),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(config.welcomeTitle,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(config.welcomeSubtitle, textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- SECTION MENDATANG ---
          if (upcomingEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  config.upcomingSectionTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            MasonryGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isDesktop ? (MediaQuery.of(context).size.width < 1200 ? 1 : 2) : 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: upcomingEvents.length,
              itemBuilder: (ctx, i) => itemBuilder(ctx, upcomingEvents[i]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onSeeAllUpcoming,
              child: Text("Lihat Semua ${config.title}"),
            ),
          ],
          if (isSponsorView = true) ...[
            const SizedBox(height: 40),
            const SharedSponsorSection(
              displayType: SponsorDisplayType.banner, // <--- Panggil tipe Banner
            ),
          ],
        ],
      ),
    );
  }
}