import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../domain/settings_catalog.dart';
import 'account_password_page.dart';
import 'account_profile_page.dart';
import 'device_management_page.dart';
import 'github_download_acceleration_page.dart';
import 'skin_selection_page.dart';

class SettingsNavigationDestination {
  const SettingsNavigationDestination({
    required this.itemId,
    required this.titleKey,
    required this.mobileRoute,
    required this.detailBuilder,
    required this.sectionId,
  });

  final String itemId;
  final String titleKey;
  final String mobileRoute;
  final String sectionId;
  final Widget Function(VoidCallback? onSaved) detailBuilder;

  String title(AppConfigState config) {
    return AppI18n.t(config, titleKey);
  }
}

final Map<String, SettingsNavigationDestination>
settingsNavigationDestinations = <String, SettingsNavigationDestination>{
  SettingsItemIds.skin: SettingsNavigationDestination(
    itemId: SettingsItemIds.skin,
    titleKey: 'settings.skin.selection.title',
    mobileRoute: AppRoutes.settingsSkin,
    sectionId: SettingsSectionIds.appearance,
    detailBuilder: (_) => const SkinSelectionPage(embedded: true),
  ),
  SettingsItemIds.githubDownloadAcceleration: SettingsNavigationDestination(
    itemId: SettingsItemIds.githubDownloadAcceleration,
    titleKey: 'settings.github_download_acceleration.title',
    mobileRoute: AppRoutes.settingsGitHubDownloadAcceleration,
    sectionId: SettingsSectionIds.general,
    detailBuilder: (_) => const GitHubDownloadAccelerationPage(embedded: true),
  ),
  SettingsItemIds.deviceManagement: SettingsNavigationDestination(
    itemId: SettingsItemIds.deviceManagement,
    titleKey: 'settings.device_management.title',
    mobileRoute: AppRoutes.settingsDevice,
    sectionId: SettingsSectionIds.account,
    detailBuilder: (_) => const DeviceManagementPage(embedded: true),
  ),
  SettingsItemIds.accountProfile: SettingsNavigationDestination(
    itemId: SettingsItemIds.accountProfile,
    titleKey: 'settings.profile.title',
    mobileRoute: AppRoutes.settingsProfile,
    sectionId: SettingsSectionIds.account,
    detailBuilder: (onSaved) =>
        AccountProfilePage(embedded: true, onSaved: onSaved),
  ),
  SettingsItemIds.accountPassword: SettingsNavigationDestination(
    itemId: SettingsItemIds.accountPassword,
    titleKey: 'settings.password.title',
    mobileRoute: AppRoutes.settingsPassword,
    sectionId: SettingsSectionIds.account,
    detailBuilder: (onSaved) =>
        AccountPasswordPage(embedded: true, onSaved: onSaved),
  ),
};
