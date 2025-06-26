// lib/vocab_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/word.dart';
import 'services/vocab_service.dart';

class VocabPage extends StatefulWidget {
  const VocabPage({super.key});
  @override
  State<VocabPage> createState() => _VocabPageState();
}

class _VocabPageState extends State<VocabPage> {
  late List<Word> _unlearnedWords;
  late int _currentPos;
  late String _selectedLevel;

  static const Map<String, String> _levelLabels = {
    'A1': 'Beginner 1',
    'A2': 'Beginner 2',
    'B1': 'Intermediate 1',
    'B2': 'Intermediate 2',
    'C1': 'Advanced 1',
    'C2': 'Advanced 2',
  };
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  @override
  void initState() {
    super.initState();
    final svc = context.read<VocabService>();
    _selectedLevel = svc.getSelectedLevel();
    _currentPos = svc.getPosition(_selectedLevel);
    _unlearnedWords = _buildUnlearnedWords(svc);
    _clampPosition();
  }

  List<Word> _buildUnlearnedWords(VocabService svc) {
    final list = svc.wordsByLevel(_selectedLevel);
    return list.where((w) => !svc.learned.contains(svc.allWords.indexOf(w))).toList();
  }

  void _clampPosition() {
    if (_currentPos >= _unlearnedWords.length) {
      _currentPos = _unlearnedWords.isEmpty ? 0 : _unlearnedWords.length - 1;
    }
  }

  void _next() {
    final svc = context.read<VocabService>();
    if (_unlearnedWords.isEmpty) return;

    setState(() {
      final oldLen = _unlearnedWords.length;
      _unlearnedWords = _buildUnlearnedWords(svc);
      _clampPosition();
      final newLen = _unlearnedWords.length;
      if (oldLen == newLen && _currentPos < newLen - 1) {
        _currentPos++;
      }
      svc.savePosition(_selectedLevel, _currentPos);
    });

    if (_currentPos >= _unlearnedWords.length - 1) {
      final learned = svc.learnedCount(_selectedLevel);
      _showEndOfLevelDialog(learned, svc.totalByLevel(_selectedLevel));
    }
  }

  void _previous() {
    final svc = context.read<VocabService>();
    if (_unlearnedWords.isEmpty || _currentPos == 0) return;
    setState(() {
      _unlearnedWords = _buildUnlearnedWords(svc);
      _clampPosition();
      if (_currentPos > 0) {
        _currentPos--;
        svc.savePosition(_selectedLevel, _currentPos);
      }
    });
  }

  void _showEndOfLevelDialog(int learned, int total) {
    final svc = context.read<VocabService>();
    final label = _levelLabels[_selectedLevel]!;
    final idx = _levels.indexOf(_selectedLevel);
    final hasNext = idx < _levels.length - 1;
    final nextLevel = hasNext ? _levels[idx + 1] : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          learned >= total ? 'Congratulations!' : 'Level Complete',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Text(
          learned >= total
              ? 'You have learned all $total words in $label!'
              : "You've learned $learned out of $total words in $label.",
        ),
        actions: [
          if (learned < total)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _currentPos = 0;
                  svc.savePosition(_selectedLevel, 0);
                  _unlearnedWords = _buildUnlearnedWords(svc);
                });
              },
              child: const Text('Continue Level'),
            ),
          if (hasNext)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                svc.saveSelectedLevel(nextLevel);
                svc.savePosition(nextLevel, 0);
                setState(() {
                  _selectedLevel = nextLevel;
                  _currentPos = 0;
                  _unlearnedWords = _buildUnlearnedWords(svc);
                });
              },
              child: Text('Next: ${_levelLabels[nextLevel!]!}'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<VocabService>();
    final totalUnlearned = _unlearnedWords.length;
    final learnedCount = svc.learnedCount(_selectedLevel);
    final label = _levelLabels[_selectedLevel]!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        _buildHeader(context, svc, scheme),
        const SizedBox(height: 24),
        if (totalUnlearned == 0)
          _buildAllLearned(svc, label)
        else
          _buildCard(svc, scheme, totalUnlearned, learnedCount),
      ],
    );
  }

Widget _buildHeader(
  BuildContext context,
  VocabService svc,
  ColorScheme scheme,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // gradient bleu clair → bleu foncé
  final gradientColors = [
    Colors.blue.shade300,
    Colors.blue.shade600,
  ];

  // en clair : blanc ; en sombre : même gris que la carte de mot
  final dropdownBg = isDark
      ? const Color.fromARGB(255, 35, 39, 44)
      : Colors.white;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withAlpha(50),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset('assets/logo.png'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: dropdownBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLevel,
                isExpanded: true,
                dropdownColor: dropdownBg,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                iconEnabledColor: scheme.onSurface,
                items: _levels.map((lvl) {
                  final cnt = svc.totalByLevel(lvl);
                  return DropdownMenuItem(
                    value: lvl,
                    child: Text('${_levelLabels[lvl]} ($cnt)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedLevel = val;
                    _currentPos = svc.getPosition(val);
                    svc.saveSelectedLevel(val);
                    _unlearnedWords = _buildUnlearnedWords(svc);
                    _clampPosition();
                  });
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}




  Widget _buildAllLearned(VocabService svc, String label) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('All words learned in $label!', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentPos = 0;
                  svc.savePosition(_selectedLevel, 0);
                  _unlearnedWords = _buildUnlearnedWords(svc);
                });
              },
              child: const Text('Restart Level'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(VocabService svc, ColorScheme scheme, int totalUnlearned, int learnedCount) {
    final word = _unlearnedWords[_currentPos];
    final globalIdx = svc.allWords.indexOf(word);
    final isFav = svc.favorites.contains(globalIdx);
    final isLearn = svc.learned.contains(globalIdx);
    final lang = svc.getSelectedLanguage();
    final translation = lang == 'ar' ? word.translationAr : word.translation;
    final exampleText = lang == 'ar' ? word.exampleAr : word.example;

    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondary.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withAlpha(77)),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 4)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(label: Text(_levelLabels[_selectedLevel]!), backgroundColor: scheme.primary.withAlpha(25)),
                    // orange star in card
                    IconButton(
                      icon: Icon(isFav ? Icons.star : Icons.star_border),
                      color: isFav ? Colors.orange : Colors.grey,
                      onPressed: () => svc.toggleFavorite(globalIdx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(word.word, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (lang == 'ar')
                  Directionality(textDirection: TextDirection.rtl, child: Text(translation, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center))
                else
                  Text(translation, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                const Divider(height: 24, thickness: 1),
                Text(word.example, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                if (lang == 'ar')
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(exampleText, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                  )
                else
                  Text(exampleText, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), color: scheme.primary, onPressed: _previous),
                    Text('${_currentPos + 1}/$totalUnlearned', style: Theme.of(context).textTheme.bodyMedium),
                    IconButton(icon: const Icon(Icons.arrow_forward), color: scheme.primary, onPressed: _next),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: svc.totalByLevel(_selectedLevel) > 0
                        ? learnedCount / svc.totalByLevel(_selectedLevel)
                        : 0.0,
                    minHeight: 16,
                    backgroundColor: scheme.primary.withAlpha(40),
                    valueColor: AlwaysStoppedAnimation(Colors.green),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Learned: $learnedCount / ${svc.totalByLevel(_selectedLevel)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 160,
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: isLearn ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => svc.toggleLearned(globalIdx),
                child: isLearn
                    ? Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check), SizedBox(width: 8), Text('Learned', style: TextStyle(fontWeight: FontWeight.bold))])
                    : const Text('Learned', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
