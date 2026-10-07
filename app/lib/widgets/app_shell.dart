import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adaptive app frame: sidebar rail on wide screens (webapp feel),
/// bottom bar on narrow ones (mobile feel). Screens declare their tab.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.tab,
    required this.title,
    required this.body,
    this.actions = const [],
    this.fab,
  });

  final AppTab tab;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: tab.index,
                  onDestinationSelected: (i) =>
                      context.go(AppTab.values[i].route),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final t in AppTab.values)
                      NavigationRailDestination(
                        icon: Icon(t.icon),
                        label: Text(t.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Scaffold(
                    appBar: AppBar(title: Text(title), actions: actions),
                    body: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: body,
                      ),
                    ),
                    floatingActionButton: fab,
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          body: body,
          floatingActionButton: fab,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (i) => context.go(AppTab.values[i].route),
            destinations: [
              for (final t in AppTab.values)
                NavigationDestination(icon: Icon(t.icon), label: t.label),
            ],
          ),
        );
      },
    );
  }
}

enum AppTab {
  pipeline('/', 'Pipeline', Icons.view_kanban_outlined),
  contacts('/contacts', 'Contacts', Icons.people_outline),
  chat('/chat', 'Chat', Icons.chat_bubble_outline),
  settings('/settings', 'Settings', Icons.settings_outlined);

  const AppTab(this.route, this.label, this.icon);

  final String route;
  final String label;
  final IconData icon;
}
