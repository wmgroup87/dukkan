import 'package:flutter/material.dart';
import 'package:dukkan/pages/notifications_page.dart';
import 'package:dukkan/pages/user_profile_page.dart';
import 'package:dukkan/pages/search_page.dart';
import 'package:dukkan/services/app_language.dart';

class FloatingTopBar extends StatelessWidget {
  final String? title;
  final bool showBack;
  final bool showNotifications;
  final bool showProfile;
  final bool showSearch;
  final bool showSettings;
  final bool showLanguage;
  final IconData? notificationIcon;
  final IconData? profileIcon;
  final IconData? backIcon;
  final IconData? settingsIcon;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSettingsPressed;

  const FloatingTopBar({
    this.title,
    this.showBack = true,
    this.showNotifications = true,
    this.showProfile = true,
    this.showSearch = false,
    this.showSettings = false,
    this.showLanguage = false,
    this.notificationIcon = Icons.notifications_none,
    this.profileIcon = Icons.person_outline,
    this.backIcon = Icons.arrow_back,
    this.settingsIcon = Icons.settings,
    this.onNotificationPressed,
    this.onProfilePressed,
    this.onBackPressed,
    this.onSettingsPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            if (showBack && Navigator.canPop(context))
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.03),
                child: IconButton(
                  icon: Icon(backIcon, size: 20),
                  onPressed:
                      onBackPressed ?? () => Navigator.of(context).maybePop(),
                ),
              )
            else
              const SizedBox(width: 40),
            const SizedBox(width: 8),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              )
            else
              const Spacer(),
            // Notifications
            if (showNotifications)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.06),
                child: IconButton(
                  icon: Icon(notificationIcon, size: 20),
                  onPressed:
                      onNotificationPressed ??
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                      },
                ),
              ),
            if (showNotifications) const SizedBox(width: 8),
            const SizedBox(width: 8),
            // Profile
            if (showProfile)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.06),
                child: IconButton(
                  icon: Icon(profileIcon, size: 20),
                  onPressed:
                      onProfilePressed ??
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UserProfilePage(userId: ''),
                          ),
                        );
                      },
                ),
              ),
            const SizedBox(width: 8),
            // Settings
            if (showSettings)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.06),
                child: IconButton(
                  icon: Icon(settingsIcon, size: 20),
                  onPressed: onSettingsPressed,
                ),
              ),
            if (showSettings) const SizedBox(width: 8),
            if (showLanguage)
              ValueListenableBuilder<String>(
                valueListenable: AppLanguage.instance.lang,
                builder: (context, lang, _) {
                  final label = lang == 'ar' ? 'عربي' : 'English';

                  return PopupMenuButton<String>(
                    borderRadius: BorderRadius.circular(20),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'ar', child: Text('العربية')),
                      PopupMenuItem(value: 'en', child: Text('English')),
                    ],
                    onSelected: (v) => AppLanguage.instance.set(v),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (showLanguage) const SizedBox(width: 8),
            // Search
            if (showSearch)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.06),
                child: IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
