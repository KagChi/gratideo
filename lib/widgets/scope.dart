import 'package:flutter/widgets.dart';

import '../data/settings.dart';

class SettingsScope extends InheritedNotifier<Settings> {
  const SettingsScope({super.key, required Settings settings, required super.child}) : super(notifier: settings);

  static Settings of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
