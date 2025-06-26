// lib/list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/vocab_service.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  String _selectedLevel   = 'A1';
  String _searchTerm       = '';
  final _levels           = const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc      = context.watch<VocabService>();
    final allWords = svc.allWords;
    final lang     = svc.getSelectedLanguage();

    // Si un terme de recherche est présent, on recherche dans **tous** les mots
    final filtered = _searchTerm.isEmpty
        ? svc.wordsByLevel(_selectedLevel)
        : allWords.where((w) =>
            w.word.toLowerCase().startsWith(_searchTerm.toLowerCase())
          ).toList();

    return Column(
      children: [
        const SizedBox(height: 16),

        // Barre de recherche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Recherche…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchTerm = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() {
              _searchTerm = val.trim();
            }),
          ),
        ),

        const SizedBox(height: 12),

        // Dropdown de niveau (désactivé dès qu'on recherche)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: _selectedLevel,
            onChanged: _searchTerm.isEmpty
                ? (val) => setState(() => _selectedLevel = val ?? _selectedLevel)
                : null,
            decoration: InputDecoration(
              labelText: 'Select Level',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _levels
                .map((lvl) => DropdownMenuItem(
                      value: lvl,
                      child: Text('Level $lvl'),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Liste des mots
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final word      = filtered[i];
              final idxGlobal = allWords.indexOf(word);
              final isFav     = svc.favorites.contains(idxGlobal);
              final isLearned = svc.learned.contains(idxGlobal);

              final textColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (lang == 'ar')
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(word.translationAr),
                    )
                  else
                    Text(word.translation),
                ],
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: textColumn,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isFav ? Icons.star : Icons.star_border),
                        color: isFav ? Colors.orange : null,
                        onPressed: () => svc.toggleFavorite(idxGlobal),
                      ),
                      IconButton(
                        icon: Icon(isLearned
                            ? Icons.check_box
                            : Icons.check_box_outline_blank),
                        color: isLearned ? Colors.green : null,
                        onPressed: () => svc.toggleLearned(idxGlobal),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
