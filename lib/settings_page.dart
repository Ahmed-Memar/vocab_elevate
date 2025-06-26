// lib/settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/vocab_service.dart';
import 'services/notification_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final svc          = context.watch<VocabService>();
    final selectedLang = svc.getSelectedLanguage();
    final reminderOn   = svc.isReminderEnabled();
    final reminderTime = svc.getReminderTime();

    const languageNames = {
      'ar': 'Arabic',
      'en': 'English',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),

        // ── Translation Language ─────────────────────────────────
        ListTile(
          title: const Text('Translation Language'),
          subtitle: Text(languageNames[selectedLang]!),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, svc),
        ),
        const Divider(),

        // ── Dark-mode toggle ─────────────────────────────────────
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Enable dark theme'),
          value: svc.isDarkMode(),
          onChanged: svc.setDarkMode,
          secondary: const Icon(Icons.dark_mode),
        ),
        const Divider(),

        // ── Daily reminder toggle ────────────────────────────────
        SwitchListTile(
          title: const Text('Daily Reminder'),
          subtitle: Text(
            reminderOn ? 'At ${reminderTime.format(context)}' : 'Disabled',
          ),
          value: reminderOn,
          onChanged: svc.setReminderEnabled,
          secondary: const Icon(Icons.alarm),
        ),

        // ── Reminder Time ────────────────────────────────────────
        ListTile(
          title: const Text('Reminder Time'),
          subtitle: Text(reminderTime.format(context)),
          enabled: reminderOn,
          trailing: const Icon(Icons.schedule),
          onTap: reminderOn
              ? () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: reminderTime,
                  );
                  if (picked != null) {
                    svc.setReminderTime(picked);
                  }
                }
              : null,
        ),
        const Divider(),

        // ── Debug notifications ─────────────────────────────────
        Text(
          'Debug notifications',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Show test notification now'),
          onTap: () => NotificationService.showTestNotification(),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Schedule a notification in 1 minute'),
          onTap: () => NotificationService.scheduleInOneMinute(),
        ),
        const Divider(),

        // ── Reset Progress ───────────────────────────────────────
        ListTile(
          title: const Text('Reset Progress'),
          subtitle: const Text('Choose levels to reset'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showResetProgressDialog(context, svc),
        ),
        const Divider(),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Dialog pour changer de langue
  void _showLanguageDialog(BuildContext context, VocabService svc) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String tempLang = svc.getSelectedLanguage();
        return AlertDialog(
          title: const Text('Select Translation Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['ar', 'en'].map((code) {
              return RadioListTile<String>(
                title: Text(code == 'ar' ? 'Arabic' : 'English'),
                value: code,
                groupValue: tempLang,
                onChanged: (val) {
                  if (val != null) {
                    tempLang = val;
                    (ctx as Element).markNeedsBuild();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                svc.saveSelectedLanguage(tempLang);
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Dialog pour reset progress
  void _showResetProgressDialog(BuildContext context, VocabService svc) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final levels = svc.allWords.map((w) => w.level).toSet().toList()..sort();
        List<String> selection = [];
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return AlertDialog(
              title: const Text('Reset Progress'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All Levels'),
                      value: selection.contains('All'),
                      onChanged: (val) => setState(() {
                        if (val == true) {
                          selection = ['All'];
                        } else {
                          selection.clear();
                        }
                      }),
                    ),
                    const Divider(),
                    ...levels.map((lvl) => CheckboxListTile(
                          title: Text('Level $lvl'),
                          value: selection.contains(lvl),
                          onChanged: selection.contains('All')
                              ? null
                              : (val) => setState(() {
                                    if (val == true) {
                                      selection.add(lvl);
                                    } else {
                                      selection.remove(lvl);
                                    }
                                  }),
                        )),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: selection.isEmpty
                      ? null
                      : () {
                          if (selection.contains('All')) {
                            svc.resetAllProgress();
                          } else {
                            svc.resetProgressForLevels(selection);
                          }
                          Navigator.pop(ctx);
                        },
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
