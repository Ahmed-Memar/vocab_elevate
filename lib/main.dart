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

/// (optionnel) – navigation depuis un tap sur notification
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1) Permission POST_NOTIFICATIONS (Android 13+) ────────────────
  if (await Permission.notification.isDenied) {
    final res = await Permission.notification.request();
    debugPrint('🔑 Notification permission = ${res.isGranted}');
  }

  // ── 2) Initialisation des notifications (timezone + canaux) ──────
  await NotificationService.init();

  // ── 3) Init Hive + enregistre l’adapter Word ─────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());

  // NB : on *ne* supprime plus les boxes à chaque démarrage.
  // Si la box 'words' est vide on (ré)importe le CSV.
  final words = await Hive.openBox<Word>('words');
  if (words.isEmpty) await _importCsvVocabAr(words);

  // Autres boxes
  await Hive.openBox<int>('favorites');
  await Hive.openBox<int>('learned');
  await Hive.openBox<int>('positions');
  await Hive.openBox<String>('settings');

  runApp(
    ChangeNotifierProvider(
      create: (_) => VocabService(),
      child: const MyApp(),
    ),
  );
}

/// Import CSV unique (VOCAB_AR.csv)
Future<void> _importCsvVocabAr(Box<Word> box) async {
  final raw = await rootBundle.loadString('assets/data/VOCAB_AR.csv');
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(raw);
  if (rows.length < 2) throw Exception('CSV vide / invalide');

  final hdr = rows.first.map((e) => e.toString().trim()).toList();
  final iHw      = hdr.indexOf('headword');
  final iLvl     = hdr.indexOf('CEFR');
  final iExEn    = hdr.indexOf('example_en');
  final iTrAr    = hdr.indexOf('translation_ar');
  final iExAr    = hdr.indexOf('example_ar');

  if ([iHw, iLvl, iExEn, iTrAr, iExAr].any((i) => i < 0)) {
    throw Exception('En-têtes manquants dans VOCAB_AR.csv : $hdr');
  }

  for (final row in rows.skip(1)) {
    if (row.length <= iExAr) continue;
    final hw = row[iHw].toString().trim();
    if (hw.isEmpty) continue;

    await box.add(
      Word(
        word:         hw,
        translation:  '',                    // anglais->fr ou autre si besoin
        example:      row[iExEn].toString(),
        level:        row[iLvl].toString().trim(),
        translationAr: row[iTrAr].toString(),
        exampleAr:     row[iExAr].toString(),
      ),
    );
  }
  debugPrint('✅ ${box.length} mots importés dans Hive');
}

/// ────────────────────────────────────────────────────────────────────
/// UI
/// ────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<VocabService>();

    return MaterialApp(
      title: 'VocabElevate',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: svc.isDarkMode() ? ThemeMode.dark : ThemeMode.light,

      // Thème clair
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F7FF),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),

      // Thème sombre
      darkTheme: ThemeData.dark().copyWith(
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
        ),
      ),

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
      // ──────────── ESPACE BANDEAU PUB tout en haut ─────────────
      // Remplacez SizedBox par votre widget pub (AdWidget, etc.)
      body: Column(
        children: [
          const SizedBox(
            height: 60,               // <-- hauteur réservée
            child: ColoredBox(color: Colors.transparent),
          ),
          Expanded(
            child: SafeArea(
              top: false,             // on gère la top-safe dans le bandeau
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
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        type: BottomNavigationBarType.fixed,
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