import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../domain/settings_catalog.dart';
import 'account_password_page.dart';
import 'account_profile_page.dart';
import 'about_page.dart';
import 'device_management_page.dart';

class SettingsNavigationDestination {
  const SettingsNavigationDestination({
    required this.itemId,
    required this.titleKey,
    required this.mobileRoute,
    required this.desktopBuilder,
  });

  final String itemId;
  final String titleKey;
  final String mobileRoute;
  final WidgetBuilder desktopBuilder;

  String title(AppConfigState config) {
    return AppI18n.t(config, titleKey);
  }
}

final Map<String, SettingsNavigationDestination>
settingsNavigationDestinations = <String, SettingsNavigationDestination>{
  SettingsItemIds.about: SettingsNavigationDestination(
    itemId: SettingsItemIds.about,
    titleKey: 'settings.about.title',
    mobileRoute: AppRoutes.about,
    desktopBuilder: (_) => const AboutPage(embedded: true),
  ),
  SettingsItemIds.deviceManagement: SettingsNavigationDestination(
    itemId: SettingsItemIds.deviceManagement,
    titleKey: 'settings.device_management.title',
    mobileRoute: AppRoutes.settingsDevice,
    desktopBuilder: (_) => const DeviceManagementPage(embedded: true),
  ),
  SettingsItemIds.accountProfile: SettingsNavigationDestination(
    itemId: SettingsItemIds.accountProfile,
    titleKey: 'settings.profile.title',
    mobileRoute: AppRoutes.settingsProfile,
    desktopBuilder: (_) => const AccountProfilePage(embedded: true),
  ),
  SettingsItemIds.accountPassword: SettingsNavigationDestination(
    itemId: SettingsItemIds.accountPassword,
    titleKey: 'settings.password.title',
    mobileRoute: AppRoutes.settingsPassword,
    desktopBuilder: (_) => const AccountPasswordPage(embedded: true),
  ),
};
