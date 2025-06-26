// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/word.dart';
import 'services/vocab_service.dart';
import 'vocab_page.dart';
import 'favorites_page.dart';
import 'list_page.dart';
import 'settings_page.dart';
import 'services/notification_service.dart';

/// (Optionnel) pour naviguer depuis le callback de notification
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0️⃣ Demande runtime de permission notifications
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    final result = await Permission.notification.request();
    debugPrint('⚠️ Permission.notification.request() → granted=${result.isGranted}');
  } else {
    debugPrint('ℹ️ Permission already granted');
  }

  // 1️⃣ Init notifications (timezone + channels + callback)
  await NotificationService.init();

  // 2️⃣ (Optionnel) gérer cold start par notification
  final launch = await NotificationService.plugin.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp == true) {
    debugPrint('🔔 Launch depuis notif, payload=${launch!.notificationResponse?.payload}');
    // navigatorKey.currentState?.pushNamed('/vocab', arguments: launch.notificationResponse?.payload);
  }

  // 3️⃣ Init Hive & adapter
  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());

  // 4️⃣ Supprime les anciennes boxes
  for (final name in ['words', 'favorites', 'learned', 'positions', 'settings']) {
    await Hive.deleteBoxFromDisk(name);
  }

  // 5️⃣ Ouvre puis importe le CSV unique
  final wordBox = await Hive.openBox<Word>('words');
  await _importCsvSingle(wordBox);

  // 6️⃣ Ouvre les boxes auxiliaires
  await Hive.openBox<int>('favorites');
  await Hive.openBox<int>('learned');
  await Hive.openBox<int>('positions');
  await Hive.openBox<String>('settings');

  // 7️⃣ Lancement de l’app
  runApp(
    ChangeNotifierProvider(
      create: (_) => VocabService(),
      child: const MyApp(),
    ),
  );
}

/// Charge, parse et stocke le CSV unique
Future<void> _importCsvSingle(Box<Word> box) async {
  final raw = await rootBundle.loadString('assets/data/VOCAB_AR.csv');
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(raw);
  if (rows.length < 2) throw Exception('CSV VOCAB_AR.csv vide ou invalide');

  final header = rows.first.map((e) => e.toString().trim()).toList();
  final iHw      = header.indexOf('headword');
  final iLvl     = header.indexOf('CEFR');
  final iExEn    = header.indexOf('example_en');
  final iTransAr = header.indexOf('translation_ar');
  final iExAr    = header.indexOf('example_ar');

  if ([iHw, iLvl, iExEn, iTransAr, iExAr].any((i) => i < 0)) {
    throw Exception('En-tête invalide dans VOCAB_AR.csv : $header');
  }

  await box.clear();
  for (var row in rows.skip(1)) {
    if (row.length <= [iHw, iLvl, iExEn, iTransAr, iExAr].reduce((a, b) => a > b ? a : b)) {
      continue;
    }
    final hw       = row[iHw].toString().trim();
    if (hw.isEmpty) continue;
    final lvl      = row[iLvl].toString().trim();
    final exEn     = row[iExEn].toString();
    final transAr  = row[iTransAr].toString();
    final exAr     = row[iExAr].toString();

    await box.add(Word(
      word:         hw,
      translation:  '',
      example:      exEn,
      level:        lvl,
      translationAr: transAr,
      exampleAr:     exAr,
    ));
  }

  debugPrint('✅ Import CSV unique terminé : ${box.length} mots');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final svc = context.watch<VocabService>();
    return MaterialApp(
      title: 'VocabElevate',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F7FF),
      ),
      darkTheme: ThemeData.dark(),
      themeMode: svc.isDarkMode() ? ThemeMode.dark : ThemeMode.light,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab,
          children: const [
            VocabPage(),
            FavoritesPage(),
            ListPage(),
            SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),     label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Fav'),
          BottomNavigationBarItem(icon: Icon(Icons.list),     label: 'List'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
