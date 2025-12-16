import 'package:firebase_ui_auth/firebase_ui_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/provider/auth_provider.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/provider/konser_provider.dart';
import 'package:wargabut/app/ui/screens/chat/gemini_firebase.dart';
import 'package:wargabut/app/ui/screens/create/create_event.dart';
import 'package:wargabut/app/ui/screens/detail/event_detail.dart';
import 'package:wargabut/app/ui/screens/event_list/event_list.dart';
import 'package:wargabut/app/ui/screens/home/event_list_page.dart';
import 'package:wargabut/app/ui/screens/home/welcome.dart';
import 'package:wargabut/theme.dart';
import 'app/provider/location_provider.dart';
import 'app/provider/theme_provider.dart';
import 'app/provider/transit_provider.dart';
import 'app/ui/screens/chat/chat_bot.dart';
import 'app/ui/screens/dkonser/konser_list_page.dart';
import 'firebase_options.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

// --- PUSAT KONFIGURASI APLIKASI ---

void main() async {
  // 1. Inisialisasi dasar
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Menghilangkan # dari URL web

  // 2. Inisialisasi Firebase & service lain
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('chat');

  // if (kIsWeb) { // Only for web platform
  //   try {
  //     await FirebaseAppCheck.instance.activate(
  //       webProvider: ReCaptchaV3Provider('6LfDTa0rAAAAALTcuZKv-tNYuGaRrQQUZCyj805b'), // IMPORTANT: Replace with your actual key
  //     );
  //     print('Firebase App Check activated successfully for web.');
  //   } catch (e) {
  //     print('Error activating Firebase App Check for web: $e');
  //   }
  // }

  await initializeDateFormatting('id_ID', null);

  // Initialize the Gemini Developer API backend service
  // Create a `GenerativeModel` instance with a model that supports your use case
  // try {
  //   final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash'); // Ensure model name is correct
  //
  //   // Provide a prompt that contains text
  //   final prompt = [Content.text('Ada Event jejepangan apa saja di akhir agustus 2025')];
  //
  //   // To generate text output, call generateContent with the text input
  //   final response = await model.generateContent(prompt);
  //   print('Firebase AI Response: ${response.text}');
  // } catch (e) {
  //   print('Error with Firebase AI: $e'); // This is where your App Check error is likely originating
  // }

  await initLocalStorage();

  // 3. Buat SATU instance untuk AuthProvider dan Router
  final authProvider = AuthProvider(); // Dibuat sekali untuk seluruh aplikasi
  final initialRoute = await _getInitialRoute();

  final router = GoRouter(
    initialLocation: initialRoute,
    // Router "mendengarkan" perubahan dari authProvider
    refreshListenable: authProvider,
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => SignInScreen(
          showAuthActionSwitch: false,
          providers: [EmailAuthProvider()],
          actions: [
            AuthStateChangeAction<SignedIn>((context, state) => context.go('/jeventku')),
            AuthStateChangeAction<UserCreated>((context, state) => context.go('/jeventku')),
          ],
        ),
      ),
      GoRoute(
        path: '/jeventku',
        builder: (context, state) => const EventListPage(),
      ),
      GoRoute(
        path: '/dkonser',
        builder: (context, state) => const KonserListPage(),
      ),
      GoRoute(
        path: '/jeventku/baru',
        builder: (context, state) => const CreateEventPage(),
        redirect: (context, state) {
          // Validasi admin menggunakan instance authProvider yang sama
          if (!authProvider.isAdmin) {
            return '/jeventku'; // Arahkan jika bukan admin
          }
          return null; // Izinkan jika admin
        },
      ),
      GoRoute(
        path: '/jeventku/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          final data = state.extra as Map<String, dynamic>?;
          return EventDetailPage(eventId: eventId, data: data);
        },
      ),
      GoRoute(
        path: '/wguide',
        builder: (context, state) => const WGuidePage(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('404 - Halaman Tidak Ditemukan')),
    ),
  );

  // 4. Jalankan aplikasi dengan MultiProvider di level tertinggi
  runApp(
    MultiProvider(
      providers: [
        // Gunakan .value untuk instance yang sudah dibuat
        ChangeNotifierProvider.value(value: authProvider),
        // Buat EventProvider dan langsung panggil fetchData
        ChangeNotifierProvider(create: (_) => EventProvider()..fetchData()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TransitProvider()),
        ChangeNotifierProvider(create: (_) => KonserProvider()),
      ],
      child: MyApp(router: router, initialRoute: '',),
    ),
  );
}

Future<String> _getInitialRoute() async {
  DateTime now = DateTime.now();

  String? lastVisit;

  // 🔹 Ambil data lastVisit sesuai platform
  if (kIsWeb) {
    lastVisit = localStorage.getItem('lastVisit');
  } else {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    lastVisit = prefs.getString('lastVisit');
  }

  if (lastVisit == null) {
    return '/welcome';
  }

  // 🔹 Hitung selisih hari
  DateTime lastVisitDate = DateFormat('yyyy-MM-dd').parse(lastVisit!);
  int daysDiff = now.difference(lastVisitDate).inDays;

  // 🔹 Jika lebih dari 7 hari → tampilkan welcome lagi dan update tanggal
  if (daysDiff >= 7) {
    return '/welcome';
  }

  // 🔹 Jika masih dalam 7 hari → langsung ke /jeventku
  return '/jeventku';
}

// 5. MyApp menjadi StatelessWidget yang bersih
class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router, required String initialRoute});

  @override
  Widget build(BuildContext context) {
    // Dengan MultiProvider di atas, kita bisa `watch` provider di sini jika perlu
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Wargabut - Media Rekomendasi Hobi',
      // Contoh penggunaan tema dasar, Anda bisa kembangkan lebih lanjut
      theme: ThemeData(
        colorScheme: MaterialTheme.lightScheme().toColorScheme(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: MaterialTheme.darkScheme().toColorScheme(),
        useMaterial3: true,
      ),
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}