import 'package:flutter/material.dart';

enum SettingsItemKind { select, toggle, navigation }

class SettingsSectionNode {
  const SettingsSectionNode({
    required this.id,
    required this.titleKey,
    required this.icon,
  });

  final String id;
  final String titleKey;
  final IconData icon;
}

class SettingsGroupNode {
  const SettingsGroupNode({
    required this.id,
    required this.sectionId,
    required this.titleKey,
  });

  final String id;
  final String sectionId;
  final String titleKey;
}

class SettingsItemNode {
  const SettingsItemNode({
    required this.id,
    required this.sectionId,
    required this.groupId,
    required this.titleKey,
    required this.kind,
    required this.icon,
    this.keywords = const <String>[],
  });

  final String id;
  final String sectionId;
  final String groupId;
  final String titleKey;
  final SettingsItemKind kind;
  final IconData icon;
  final List<String> keywords;
}
