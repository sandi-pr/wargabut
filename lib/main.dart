import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/provider/aninews_provider.dart';
import 'package:wargabut/app/provider/auth_provider.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/provider/konser_provider.dart';
import 'package:wargabut/app/ui/screens/chat/gemini_firebase.dart';
import 'package:wargabut/app/ui/screens/create/create_ani_news.dart';
import 'package:wargabut/app/ui/screens/create/create_event.dart';
import 'package:wargabut/app/ui/screens/detail/event_detail.dart';
import 'package:wargabut/app/ui/screens/admin/storage_cleanup_page.dart';
import 'package:wargabut/app/ui/screens/list/aninews_list_page.dart';
import 'package:wargabut/app/ui/screens/list/event_list_page.dart';
import 'package:wargabut/app/ui/screens/home/welcome.dart';
import 'package:wargabut/theme.dart';
import 'app/ui/screens/tanya_maps/tanya_maps_page.dart';
import 'app/provider/location_provider.dart';
import 'app/provider/theme_provider.dart';
import 'app/provider/transit_provider.dart';
import 'app/provider/community_provider.dart';
import 'app/provider/profile_provider.dart';
import 'app/provider/companion_provider.dart';
import 'app/models/community_model.dart';
import 'app/ui/screens/auth/custom_auth_page.dart';
import 'app/ui/screens/community/community_list_page.dart';
import 'app/ui/screens/community/create_community_page.dart';
import 'app/ui/screens/community/community_detail_page.dart';
import 'app/ui/screens/community/community_manage_page.dart';
import 'app/ui/screens/profile/edit_profile_biodata_page.dart';
import 'app/ui/screens/profile/member_profile_page.dart';
import 'app/ui/screens/admin/admin_community_verification_page.dart';
import 'app/ui/screens/create/create_festival.dart';
import 'app/ui/screens/detail/ani_news_detail.dart';
import 'app/ui/screens/detail/konser_detail.dart';
import 'app/ui/screens/list/konser_list_page.dart';
import 'app/provider/cosplay_project_provider.dart';
import 'app/models/cosplay_project_model.dart';
import 'app/ui/screens/cosplay_project/cosplay_project_list_page.dart';
import 'app/ui/screens/cosplay_project/cosplay_project_detail_page.dart';
import 'app/ui/screens/cosplay_project/create_cosplay_project_page.dart';
import 'app/ui/screens/wear/connect_wear_page.dart';
import 'firebase_options.dart';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

// --- PUSAT KONFIGURASI APLIKASI ---

void main() async {
  // 1. Inisialisasi dasar
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env", isOptional: true);
  } catch (e) {
    debugPrint("Failed to load .env: $e");
  }
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
        builder: (context, state) => const CustomAuthPage(),
      ),
      GoRoute(
        path: '/jeventku',
        builder: (context, state) => const EventListPage(),
      ),
      GoRoute(
        path: '/anichekku',
        builder: (context, state) => const AniNewsListPage(),
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
        path: '/anichekku/baru',
        builder: (context, state) => const CreateAniNewsPage(),
        redirect: (context, state) {
          // Validasi admin menggunakan instance authProvider yang sama
          if (!authProvider.isAdmin) {
            return '/anichekku'; // Arahkan jika bukan admin
          }
          return null; // Izinkan jika admin
        },
      ),
      GoRoute(
        path: '/dkonser/baru',
        builder: (context, state) => const CreateKonserPage(),
        redirect: (context, state) {
          // Validasi admin menggunakan instance authProvider yang sama
          if (!authProvider.isAdmin) {
            return '/dkonser'; // Arahkan jika bukan admin
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
        path: '/anichekku/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          final data = state.extra as Map<String, dynamic>?;
          return AniNewsDetailPage(newsId: eventId, data: data);
        },
      ),
      GoRoute(
        path: '/dkonser/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          final data = state.extra as Map<String, dynamic>?;
          return KonserDetailPage(eventId: eventId, data: data);
        },
      ),
      GoRoute(
        path: '/dcosplay',
        builder: (context, state) => const CosplayProjectListPage(),
      ),
      GoRoute(
        path: '/dcosplay/baru',
        builder: (context, state) => const CreateCosplayProjectPage(),
        redirect: (context, state) {
          if (!authProvider.isLoggedIn) return '/login?from=${state.matchedLocation}';
          return null;
        },
      ),
      GoRoute(
        path: '/dcosplay/:projectId',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return CosplayProjectDetailPage(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/dcosplay/:projectId/edit',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          final project = state.extra as CosplayProjectModel?;
          return CreateCosplayProjectPage(projectId: projectId, projectToEdit: project);
        },
        redirect: (context, state) {
          if (!authProvider.isLoggedIn) return '/login?from=${state.matchedLocation}';
          return null;
        },
      ),
      GoRoute(
        path: '/wguide',
        builder: (context, state) => const WGuidePage(),
      ),
      GoRoute(
        path: '/tanya-maps',
        builder: (context, state) => const TanyaMapsPage(),
        redirect: (context, state) {
          if (!authProvider.isAdmin) {
            return '/jeventku';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/admin/storage',
        builder: (context, state) => const StorageCleanupPage(),
        redirect: (context, state) {
          if (!authProvider.isAdmin) {
            return '/jeventku';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/komunitas',
        builder: (context, state) => const CommunityListPage(),
      ),
      GoRoute(
        path: '/komunitas/baru',
        builder: (context, state) => const CreateCommunityPage(),
        redirect: (context, state) {
          if (!authProvider.isLoggedIn) return '/login?from=${state.matchedLocation}';
          return null;
        },
      ),
      GoRoute(
        path: '/komunitas/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return CommunityDetailPage(slug: slug);
        },
      ),
      GoRoute(
        path: '/komunitas/:slug/kelola',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return CommunityManagePage(slug: slug);
        },
        redirect: (context, state) {
          if (!authProvider.isLoggedIn) return '/login?from=${state.matchedLocation}';
          return null;
        },
      ),
      GoRoute(
        path: '/komunitas/:slug/edit',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final community = state.extra as CommunityModel?;
          return CreateCommunityPage(communityToEdit: community, communitySlug: slug);
        },
        redirect: (context, state) {
          if (!authProvider.isLoggedIn) return '/login?from=${state.matchedLocation}';
          return null;
        },
      ),
      GoRoute(
        path: '/wear',
        builder: (context, state) => const ConnectWearPage(),
      ),
      GoRoute(
        path: '/@me',
        builder: (context, state) => const EditProfileBiodataPage(),
        redirect: (context, state) {
          if (!authProvider.isLoggedIn) return '/login?from=/@me';
          return null;
        },
      ),
      GoRoute(
        path: '/admin/komunitas',
        builder: (context, state) => const AdminCommunityVerificationPage(),
        redirect: (context, state) {
          if (!authProvider.isAdmin) return '/komunitas';
          return null;
        },
      ),
      GoRoute(
        path: '/@:username',
        builder: (context, state) {
          final username = state.pathParameters['username']!;
          return MemberProfilePage(username: username);
        },
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
        ChangeNotifierProvider(create: (_) => KonserProvider()..fetchData()),
        ChangeNotifierProvider(create: (_) => AniNewsProvider()..fetchData()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TransitProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => CompanionProvider()),
        ChangeNotifierProvider(create: (_) => CosplayProjectProvider()),
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
  DateTime lastVisitDate = DateFormat('yyyy-MM-dd').parse(lastVisit);
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