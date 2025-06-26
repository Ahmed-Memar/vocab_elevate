// lib/favorites_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/vocab_service.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final svc      = context.watch<VocabService>();
    final allWords = svc.allWords;
    final favIdxs  = svc.favorites.toList();
    final favCount = favIdxs.length;
    final lang     = svc.getSelectedLanguage();

    if (favCount == 0) {
      return const Center(child: Text('Aucun favori pour l’instant.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Favoris : $favCount mots',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favIdxs.length,
            itemBuilder: (ctx, i) {
              final globalIdx = favIdxs[i];
              final word      = allWords[globalIdx];

              // Colonne pour superposer mot & traduction
              final textColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                        icon: const Icon(Icons.star),
                        color: Colors.orange,
                        onPressed: () =>
                            context.read<VocabService>().toggleFavorite(globalIdx),
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
