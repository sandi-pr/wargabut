import 'package:flutter/material.dart';
import 'package:wargabut/app/ui/screens/event_list/event_list.dart';
import 'package:wargabut/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wargabut - Media Rekomendasi Hobi',
      theme: ThemeData(
        colorScheme: MaterialTheme.lightScheme().toColorScheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: MaterialTheme.darkScheme().toColorScheme(),
      ),
      home: const EventList(),
    );
  }
}
