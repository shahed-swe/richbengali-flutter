import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../state/favorites_provider.dart';
import '../../widgets/widgets.dart';
import '../../theme/theme.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0xFFf9fafb))),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Favorites',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPink,
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: favAsync.when(
              loading: () =>
                  const Center(child: AnimatedLogo(size: 80)),
              error: (e, _) => Center(
                child: Text(
                  'Error loading favorites',
                  style: TextStyle(color: AppColors.gray500),
                ),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.heart,
                    title: 'No Favorites Yet',
                    description:
                        'Start swiping and save people you like here!',
                    actionLabel: 'Go to Home',
                    onAction: () => context.go('/home'),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.brandPink,
                  onRefresh: () async {
                    ref.read(favoritesProvider.notifier).refresh();
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, i) => UserCard(
                      user: users[i],
                      routePrefix: '/favorites',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
