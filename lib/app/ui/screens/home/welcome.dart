import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:localstorage/localstorage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/ui/screens/home/event_list_page.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    _setVisitDate();
  }

  final Uri _url = Uri.parse('https://www.instagram.com/squid_rentcos');

  Future<void> _setVisitDate() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (kIsWeb) {
      await initLocalStorage();
      localStorage.setItem('lastVisit', today);
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastVisit', today);
    }
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if the screen width is considered a desktop layout
    bool isDesktop = MediaQuery.of(context).size.width >
        900; // You can adjust this threshold

    return Material(
      child: isDesktop
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Stack(
            children: [
              Image(
                height: 350,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                width: MediaQuery.of(context).size.width,
                image: const AssetImage('assets/images/poster_new_mascot.png'),
                filterQuality: FilterQuality.low,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 300.0),
                child: AlertDialog(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  title: const Text('Selamat Datang Wargabut!'),
                  content: const Text(
                    'Kamu bingung weekend mau kemana? \nKuy, cek event-event seru di Jventku!',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => context.go('/jeventku'),
                      child: const Text('Mulai Jelajah'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // const SizedBox(height: 8.0),
          // const Text(
          //   'Sponsor',
          //   style: TextStyle(
          //     fontWeight: FontWeight.normal,
          //     fontSize: 16,
          //     color: Colors.grey,
          //   ),
          // ),
          // const SizedBox(height: 8.0),
          // InkWell(
          //   onTap: _launchUrl,
          //   child: ConstrainedBox(
          //     constraints: const BoxConstraints(maxWidth: 300),
          //     child: Image(
          //       fit: BoxFit.cover,
          //       width: MediaQuery.of(context).size.width / 1.5,
          //       image:
          //           const AssetImage('assets/images/banner-squid_rentcos.jpg'),
          //       filterQuality: FilterQuality.medium,
          //     ),
          //   ),
          // ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Image(
          width: MediaQuery.of(context).size.width,
          height: 390,
          fit: BoxFit.cover,
          image: const AssetImage(
              'assets/images/jeventku_banner-dialog_transparent.png'),
          filterQuality: FilterQuality.low,
        ),
        Positioned(
          right: MediaQuery.of(context).size.width / 7,
          bottom: 200,
          child: const Image(
            image: AssetImage('assets/images/wargabut_mascot_chibi.png'),
            width: 300,
          ),
        ),
        Positioned(
          right: MediaQuery.of(context).size.width / 8,
          bottom: 10,
          child: AlertDialog(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            title: const Text('Selamat Datang Wargabut!'),
            content: const Text(
                'Kamu bingung weekend mau kemana? \nKuy, cek event-event seru di Jventku!'),
            actions: <Widget>[
              TextButton(
                onPressed: () => context.go('/jeventku'),
                child: const Text('Mulai Jelajah'),
              ),
            ],
          ),
        ),
        const Positioned(
          top: 50,
          left: 50,
          child: Image(
            image: AssetImage('assets/icon/wg_logo_clear.png'),
            width: 100,
          ),
        ),
        // Positioned(
        //   top: 55,
        //   right: 30,
        //   child: Column(
        //     children: [
        //       const Text(
        //         'Sponsor',
        //         style: TextStyle(
        //           fontWeight: FontWeight.normal,
        //           fontSize: 16,
        //           color: Colors.grey,
        //         ),
        //       ),
        //       const SizedBox(height: 8.0),
        //       InkWell(
        //         onTap: _launchUrl,
        //         child: ConstrainedBox(
        //           constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 1400 ? 280 : 200),
        //           child: Image(
        //             fit: BoxFit.cover,
        //             width: MediaQuery.of(context).size.width / 1.5,
        //             image:
        //                 const AssetImage('assets/images/banner-squid_rentcos.jpg'),
        //             filterQuality: FilterQuality.high,
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }
}
