import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/core/connectivity_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../products/products_screen.dart';
import '../customers/customers_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../inventory/inventory_screen.dart';
import '../pos/pos_screen.dart';
import '../purchasing/purchase_orders_screen.dart';
import '../purchasing/grn_screen.dart';
import '../quotations/quotations_screen.dart';
import '../credits/credits_screen.dart';
import '../repairs/repairs_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);

class NavigationShell extends ConsumerWidget {
  const NavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final authState = ref.watch(authNotifierProvider);
    final isOnline = ref.watch(isOnlineProvider);

    final items = _buildNavigationItems(authState.role);
    final screens = _buildScreens(authState.role);

    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(
              FluentIcons.laptop_secure,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Laptop Shop POS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sync status indicator
            _SyncStatusIndicator(isOnline: isOnline),
            const SizedBox(width: 16),
            // User info
            if (authState.user != null)
              Row(
                children: [
                  Icon(
                    FluentIcons.contact,
                    size: 20,
                    color: FluentTheme.of(context).typography.body?.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    authState.user!.email ?? 'User',
                    style: FluentTheme.of(context).typography.body,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      authState.role?.displayName ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 16),
            // Sign out button
            IconButton(
              icon: const Icon(FluentIcons.sign_out),
              onPressed: () => _showSignOutDialog(context, ref),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      pane: NavigationPane(
        selected: selectedIndex,
        onChanged: (index) {
          ref.read(selectedIndexProvider.notifier).state = index;
        },
        displayMode: PaneDisplayMode.compact,
        items: items,
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: const SettingsScreen(),
          ),
        ],
      ),
    );
  }

  List<NavigationPaneItem> _buildNavigationItems(UserRole? role) {
    final items = <NavigationPaneItem>[
      PaneItem(
        icon: const Icon(FluentIcons.view_dashboard),
        title: const Text('Dashboard'),
        body: const DashboardScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.shopping_cart),
        title: const Text('POS'),
        body: const PosScreen(),
      ),
    ];

    if (role?.canManageProducts ?? false) {
      items.addAll([
        PaneItemSeparator(),
        PaneItemHeader(header: const Text('Master Data')),
        PaneItem(
          icon: const Icon(FluentIcons.product),
          title: const Text('Products'),
          body: const ProductsScreen(),
        ),
        PaneItem(
          icon: const Icon(FluentIcons.people),
          title: const Text('Customers'),
          body: const CustomersScreen(),
        ),
        PaneItem(
          icon: const Icon(FluentIcons.factory),
          title: const Text('Suppliers'),
          body: const SuppliersScreen(),
        ),
      ]);
    }

    items.addAll([
      PaneItemSeparator(),
      PaneItemHeader(header: const Text('Purchasing')),
      PaneItem(
        icon: const Icon(FluentIcons.clipboard_list),
        title: const Text('Purchase Orders'),
        body: const PurchaseOrdersScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.download),
        title: const Text('GRN'),
        body: const GrnScreen(),
      ),
      PaneItemSeparator(),
      PaneItemHeader(header: const Text('Operations')),
      PaneItem(
        icon: const Icon(FluentIcons.archive),
        title: const Text('Inventory'),
        body: const InventoryScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.document),
        title: const Text('Quotations'),
        body: const QuotationsScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.money),
        title: const Text('Credits'),
        body: const CreditsScreen(),
      ),
    ]);

    if (role?.canManageRepairs ?? false) {
      items.add(
        PaneItem(
          icon: const Icon(FluentIcons.repair),
          title: const Text('Repairs'),
          body: const RepairsScreen(),
        ),
      );
    }

    if (role?.canViewReports ?? false) {
      items.addAll([
        PaneItemSeparator(),
        PaneItem(
          icon: const Icon(FluentIcons.report_document),
          title: const Text('Reports'),
          body: const ReportsScreen(),
        ),
      ]);
    }

    return items;
  }

  List<Widget> _buildScreens(UserRole? role) {
    // This method is not actually used since screens are defined in NavigationPane
    return [];
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _SyncStatusIndicator extends StatelessWidget {
  final bool isOnline;

  const _SyncStatusIndicator({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isOnline ? 'Online - Syncing' : 'Offline - Local mode',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOnline
              ? AppTheme.successColor.withValues(alpha: 0.1)
              : AppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? FluentIcons.cloud : FluentIcons.plug_disconnected,
              size: 14,
              color: isOnline ? AppTheme.successColor : AppTheme.warningColor,
            ),
            const SizedBox(width: 4),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                color: isOnline ? AppTheme.successColor : AppTheme.warningColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
