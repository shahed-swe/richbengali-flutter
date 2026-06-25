import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../state/auth_provider.dart';
import '../../widgets/widgets.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isMale = user?.isMale ?? false;

    // Build the visible tab items and their branch indices dynamically.
    // Branches: 0=Home, 1=Favorites, 2=Chats, 3=Plans, 4=Me
    // When Plans is hidden, branch 4 (Me) maps to visible index 3.
    final List<_TabItem> tabs = [
      const _TabItem(label: 'Home', icon: LucideIcons.home, branchIndex: 0),
      const _TabItem(label: 'Favorites', icon: LucideIcons.heart, branchIndex: 1),
      const _TabItem(label: 'Chats', icon: LucideIcons.messageCircle, branchIndex: 2),
      if (isMale)
        const _TabItem(label: 'Plans', icon: LucideIcons.crown, branchIndex: 3),
      const _TabItem(label: 'Me', icon: LucideIcons.user, branchIndex: 4),
    ];

    final double navBarHeight = Platform.isIOS ? 80.0 : 74.0;

    // Map the current shell branch index to the visible item index.
    int currentVisibleIndex = 0;
    for (int i = 0; i < tabs.length; i++) {
      if (tabs[i].branchIndex == navigationShell.currentIndex) {
        currentVisibleIndex = i;
        break;
      }
    }

    return BackgroundGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const AppHeader(),
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2FFFFFF), // ~rgba(255,255,255,0.95)
            border: Border(
              top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
            ),
          ),
          child: SizedBox(
            height: navBarHeight,
            child: BottomNavigationBar(
              currentIndex: currentVisibleIndex,
              onTap: (visibleIndex) {
                navigationShell.goBranch(
                  tabs[visibleIndex].branchIndex,
                  initialLocation:
                      tabs[visibleIndex].branchIndex == navigationShell.currentIndex,
                );
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFFE91D7C),
              unselectedItemColor: const Color(0xFF6B7280),
              selectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              items: tabs
                  .map(
                    (t) => BottomNavigationBarItem(
                      icon: Icon(t.icon, size: 24),
                      label: t.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final int branchIndex;
  const _TabItem({required this.label, required this.icon, required this.branchIndex});
}
