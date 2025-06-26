// lib/services/vocab_service.dart

import 'package:flutter/material.dart';                     // ← nécessaire pour TimeOfDay
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/word.dart';
import 'notification_service.dart';                         // ← pour schedule/cancel

class VocabService extends ChangeNotifier {
  // Boxes Hive
  final Box<Word>   _words    = Hive.box<Word>('words');
  final Box<int>    _favBox   = Hive.box<int>('favorites');
  final Box<int>    _learnBox = Hive.box<int>('learned');
  final Box<int>    _posBox   = Hive.box<int>('positions');
  final Box<String> _settings = Hive.box<String>('settings');

  // In-memory lists and index
  List<Word>                     _allWords   = [];
  late final Map<String, List<int>> _levelIndex;

  VocabService() {
    _init();
  }

  Future<void> _init() async {
    if (_words.isEmpty) {
      await _importCsvData();
    }
    _allWords    = _words.values.toList();
    _levelIndex  = _buildIndex();
    notifyListeners();
  }

  /// Charge et parse UN SEUL CSV combiné (assets/data/VOCAB_AR.csv)
  Future<void> _importCsvData() async {
    // 1) Charge le CSV unique
    final raw = await rootBundle.loadString('assets/data/VOCAB_AR.csv');
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(raw);
    if (rows.length < 2) throw Exception('CSV VOCAB_AR.csv vide ou invalide');

    // 2) Récupère les en-têtes et leurs index
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final iHw       = header.indexOf('headword');
    final iLvl      = header.indexOf('CEFR');
    final iExEn     = header.indexOf('example_en');
    final iTransAr  = header.indexOf('translation_ar');
    final iExAr     = header.indexOf('example_ar');

    if ([iHw, iLvl, iExEn, iTransAr, iExAr].any((i) => i < 0)) {
      throw Exception('En-tête invalide dans VOCAB_AR.csv : $header');
    }

    // 3) Vide la box puis ajoute chaque ligne
    await _words.clear();
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

      await _words.add(Word(
        word:         hw,
        translation:  '',       // champ inutilisé ou à adapter selon votre modèle
        example:      exEn,
        level:        lvl,
        translationAr: transAr,
        exampleAr:     exAr,
      ));
    }
    debugPrint('✅ Import CSV terminé : ${_words.length} mots dans Hive');
  }

  Map<String, List<int>> _buildIndex() {
    final map = <String, List<int>>{};
    for (var i = 0; i < _words.length; i++) {
      final lvl = _words.getAt(i)!.level;
      map.putIfAbsent(lvl, () => []).add(i);
    }
    return map;
  }

  // ─── Getters ───────────────────────────────────────────────────────
  List<Word> get allWords => _allWords;
  Set<int>   get favorites => _favBox.values.toSet();
  Set<int>   get learned   => _learnBox.values.toSet();

  List<Word> wordsByLevel(String level) {
    final idxs = _levelIndex[level] ?? [];
    return idxs.map((i) => _allWords[i]).toList();
  }

  int globalIndex(String level, int pos) => _levelIndex[level]![pos];
  Word wordAt(String level, int pos)   => _allWords[globalIndex(level, pos)];
  int totalByLevel(String level)       => _levelIndex[level]?.length ?? 0;
  int learnedCount(String level) =>
      _levelIndex[level]!.where((i) => learned.contains(i)).length;

  // position / selected level
  int getPosition(String level) =>
      _posBox.get(level, defaultValue: 0)!;
  void savePosition(String level, int idx) =>
      _posBox.put(level, idx);

  // CEFR level selection
  String getSelectedLevel() =>
      _settings.get('selectedLevel', defaultValue: 'A1')!;
  void saveSelectedLevel(String lvl) =>
      _settings.put('selectedLevel', lvl);

  // translation language
  String getSelectedLanguage() =>
      _settings.get('selectedLanguage', defaultValue: 'ar')!;
  void saveSelectedLanguage(String lang) =>
      _settings.put('selectedLanguage', lang);

  // ── Favorites & Learned ─────────────────────────────────────────────
  void toggleFavorite(int idx) { /* … inchangé … */ }
  void toggleLearned(int idx)  { /* … inchangé … */ }

  // ── Reset Progress ──────────────────────────────────────────────────
  void resetProgressForLevels(List<String> levels) { /* … inchangé … */ }
  void resetAllProgress()                         { /* … inchangé … */ }

  // ── Dark Mode ───────────────────────────────────────────────────────
  bool isDarkMode() => _settings.get('darkMode', defaultValue: 'false') == 'true';
  void setDarkMode(bool value) {
    _settings.put('darkMode', value.toString());
    notifyListeners();
  }

  // ── Daily Reminder ─────────────────────────────────────────────────
  bool isReminderEnabled() =>
      _settings.get('reminderEnabled', defaultValue: 'false') == 'true';

  TimeOfDay getReminderTime() {
    final str = _settings.get('reminderTime', defaultValue: '20:00')!; // 20h par défaut
    final parts = str.split(':').map(int.parse).toList();
    return TimeOfDay(hour: parts[0], minute: parts[1]);
  }

  void setReminderEnabled(bool on) {
    _settings.put('reminderEnabled', on.toString());
    if (on) {
      final t = getReminderTime();
      NotificationService.scheduleDailyReminder(t);
    } else {
      NotificationService.cancelReminder();
    }
    notifyListeners();
  }

  void setReminderTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    _settings.put('reminderTime', '$hh:$mm');
    if (isReminderEnabled()) {
      NotificationService.scheduleDailyReminder(t);
    }
    notifyListeners();
  }
}
