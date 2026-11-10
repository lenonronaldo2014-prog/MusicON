// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MusicColor {
  violet('Violeta', Color(0xFFB79AFF)),
  blue('Azul', Color(0xFF8CBCFF)),
  green('Verde', Color(0xFF83DDB1)),
  rose('Rosa', Color(0xFFFF9DCB)),
  amber('Dourado', Color(0xFFFFCE80)),
  coral('Coral', Color(0xFFFFA090));

  const MusicColor(this.label, this.color);
  final String label;
  final Color color;
}

class AppPreferences extends ChangeNotifier {
  MusicColor color = MusicColor.violet;
  bool autoUpdates = false;
  Future<void> _tail = Future.value();
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('musicon.color');
    color =
        MusicColor.values.where((c) => c.name == name).firstOrNull ??
        MusicColor.violet;
    autoUpdates = prefs.getBool('musicon.autoUpdates') ?? false;
    notifyListeners();
  }

  Future<void> setColor(MusicColor value) async {
    color = value;
    notifyListeners();
    return _save();
  }

  Future<void> setAutoUpdates(bool value) async {
    autoUpdates = value;
    notifyListeners();
    return _save();
  }

  Future<void> _save() {
    final name = color.name;
    final automatic = autoUpdates;
    final saved = _tail.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('musicon.color', name) ||
          !await prefs.setBool('musicon.autoUpdates', automatic)) {
        throw StateError('Não foi possível salvar as configurações.');
      }
    });
    _tail = saved;
    return saved;
  }
}
