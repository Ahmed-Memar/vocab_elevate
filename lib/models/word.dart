import 'package:hive/hive.dart';

part 'word.g.dart';

@HiveType(typeId: 0)
class Word {
  @HiveField(0)
  final String word;

  @HiveField(1)
  final String translation;

  @HiveField(2)
  final String example;

  @HiveField(3)
  final String level;

  @HiveField(4)
  final String translationAr;

  @HiveField(5)
  final String exampleAr;

  Word({
    required this.word,
    required this.translation,
    required this.example,
    required this.level,
    required this.translationAr,
    required this.exampleAr,
  });
}
