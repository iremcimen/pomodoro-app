import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/auth/application/auth_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _AppDestination(
      label: 'Odak',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
    ),
    _AppDestination(
      label: 'Görevler',
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt_rounded,
    ),
    _AppDestination(
      label: 'İstatistikler',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
    ),
    _AppDestination(
      label: 'Ayarlar',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return _WideShell(
            navigationShell: navigationShell,
            isLoggingOut: authState.isLoading,
            onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_destinations[navigationShell.currentIndex].label),
            actions: [
              _LogoutButton(
                isLoading: authState.isLoading,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                  tooltip: destination.label,
                ),
            ],
          ),
        );
      },
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.navigationShell,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final StatefulNavigationShell navigationShell;
  final bool isLoggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final extended = MediaQuery.sizeOf(context).width >= 1080;
    final destination = AppShell._destinations[navigationShell.currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                child: _BrandMark(),
              ),
              destinations: [
                for (final item in AppShell._destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Text(
                            destination.label,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          _LogoutButton(
                            isLoading: isLoggingOut,
                            onPressed: onLogout,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pomo',
      image: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cyberGrape,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: const Icon(Icons.timer_rounded, color: AppColors.acidLime),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Çıkış yap',
      onPressed: isLoading ? null : onPressed,
      icon: const Icon(Icons.logout_rounded),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
