import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/users_provider.dart';
import '../../widgets/widgets.dart';
import '../../theme/theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(userFiltersProvider);
    final usersAsync = ref.watch(visibleUsersProvider(filters));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header bar: "Discover" + filters
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(bottom: BorderSide(color: Color(0xFFf9fafb))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discover',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandPurple,
                  ),
                ),
                const UserFiltersButton(),
              ],
            ),
          ),

          // Body
          Expanded(
            child: usersAsync.when(
              loading: () =>
                  const Center(child: AnimatedLogo(size: 80)),
              error: (e, _) => Center(
                child: Text(
                  'Error loading users',
                  style: TextStyle(color: AppColors.gray500),
                ),
              ),
              data: (visible) {
                return RefreshIndicator(
                  color: AppColors.brandPink,
                  onRefresh: () async {
                    ref.read(homeHiddenUsersProvider.notifier).clear();
                    ref.invalidate(usersProvider(filters));
                  },
                  child: visible.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.3,
                            ),
                            Center(
                              child: Text(
                                'No matches found. Try adjusting filters.',
                                style:
                                    TextStyle(color: AppColors.gray500),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 3 / 4,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, i) => UserCard(
                            user: visible[i],
                            routePrefix: '/home',
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
