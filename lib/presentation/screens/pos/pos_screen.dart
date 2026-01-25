import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/payment_method.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/local/daos/sales_dao.dart';
import '../../../domain/entities/sale.dart' as entity;
import '../../providers/core/database_provider.dart';
import '../../../services/printing/receipt_printer.dart';
import '../../providers/core/settings_provider.dart';
import '../../providers/inventory/product_provider.dart';
import '../../providers/inventory/customer_provider.dart';
import '../../providers/inventory/category_provider.dart';
import '../../providers/inventory/inventory_provider.dart';
import '../../providers/sales/sales_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _selectedCategoryProvider = StateProvider<String?>((ref) => null);

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);

    // Listen for checkout success
    ref.listen<CheckoutState>(checkoutProvider, (previous, next) {
      if (next.isSuccess && next.completedSale != null) {
        _showSuccessDialog(next.completedSale!);
        ref.read(checkoutProvider.notifier).reset();
      }
      if (next.error != null) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(next.error!),
            severity: InfoBarSeverity.error,
          );
        });
      }
    });

    return Row(
      children: [
        // Products panel (left side)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: _searchController,
                        placeholder: 'Search products or scan barcode...',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(FluentIcons.search, size: 16),
                        ),
                        onChanged: (value) {
                          ref.read(_searchQueryProvider.notifier).state = value;
                        },
                        onSubmitted: (value) {
                          // Barcode scan - try to find exact match
                          _handleBarcodeSearch(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Product categories
              _buildCategoryChips(),
              const SizedBox(height: 16),
              // Products grid
              Expanded(
                child: _buildProductsGrid(),
              ),
            ],
          ),
        ),
        // Divider
        Container(
          width: 1,
          color: Colors.grey[40],
        ),
        // Cart panel (right side)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Cart header
              _buildCartHeader(cart),
              // Customer selection
              _buildCustomerSelection(cart),
              // Cart items
              Expanded(
                child: cart.isEmpty
                    ? _buildEmptyCart()
                    : _buildCartItems(cart),
              ),
              // Cart footer
              _buildCartFooter(cart, checkoutState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CategoryChip(
              label: 'All',
              isSelected: selectedCategory == null,
              onPressed: () {
                ref.read(_selectedCategoryProvider.notifier).state = null;
              },
            ),
            categoriesAsync.when(
              data: (categories) => Row(
                children: categories.map((cat) => _CategoryChip(
                      label: cat.name,
                      isSelected: selectedCategory == cat.id,
                      onPressed: () {
                        ref.read(_selectedCategoryProvider.notifier).state = cat.id;
                      },
                    )).toList(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    final searchQuery = ref.watch(_searchQueryProvider);
    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      data: (products) {
        var filtered = products.where((p) => p.isActive).toList();

        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          filtered = filtered.where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.code.toLowerCase().contains(query) ||
              (p.barcode?.toLowerCase().contains(query) ?? false)).toList();
        }

        if (selectedCategory != null) {
          filtered = filtered.where((p) => p.categoryId == selectedCategory).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.product, size: 64, color: Colors.grey[100]),
                const SizedBox(height: 16),
                Text('No products found', style: TextStyle(color: Colors.grey[100])),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              return _ProductCard(
                product: product,
                onTap: () => _addProductToCart(product),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildCartHeader(CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.grey[40]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.shopping_cart, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cart (${cart.totalQuantity})',
                style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                checked: cart.isCredit,
                content: const Text('Credit Sale'),
                onChanged: (value) {
                  ref.read(cartProvider.notifier).setIsCredit(value ?? false);
                },
              ),
              const SizedBox(width: 8),
              Button(
                child: const Text('Clear'),
                onPressed: cart.isEmpty ? null : () {
                  ref.read(cartProvider.notifier).clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelection(CartState cart) {
    final customersAsync = ref.watch(customersProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[40]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.contact, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: customersAsync.when(
              data: (customers) => ComboBox<String>(
                placeholder: const Text('Walk-in Customer'),
                value: cart.customerId,
                items: [
                  const ComboBoxItem<String>(
                    value: null,
                    child: Text('Walk-in Customer'),
                  ),
                  ...customers.map((c) => ComboBoxItem<String>(
                        value: c.id,
                        child: Text('${c.name} (${c.code})'),
                      )),
                ],
                onChanged: (value) {
                  final customer = value != null
                      ? customers.firstWhere((c) => c.id == value)
                      : null;
                  ref.read(cartProvider.notifier).setCustomer(
                        value,
                        customer?.name,
                      );
                },
                isExpanded: true,
              ),
              loading: () => const ProgressRing(),
              error: (_, __) => const Text('Error loading customers'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.shopping_cart, size: 48, color: Colors.grey[100]),
          const SizedBox(height: 16),
          Text('Cart is empty', style: TextStyle(color: Colors.grey[100])),
          const SizedBox(height: 8),
          Text(
            'Click on products to add them',
            style: TextStyle(color: Colors.grey[100], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(CartState cart) {
    return ListView.builder(
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return _CartItemTile(
          item: item,
          onQuantityChanged: (qty) {
            ref.read(cartProvider.notifier).updateQuantity(item.productId, qty);
          },
          onRemove: () {
            ref.read(cartProvider.notifier).removeProduct(item.productId);
          },
          onSelectSerials: item.trackSerials
              ? () => _showSerialSelectionDialog(item)
              : null,
        );
      },
    );
  }

  Widget _buildCartFooter(CartState cart, CheckoutState checkoutState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[40]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _CartSummaryRow(label: 'Subtotal', value: Formatters.currency(cart.subtotal)),
          const SizedBox(height: 8),
          _CartSummaryRow(label: 'Discount', value: Formatters.currency(cart.discountAmount)),
          const SizedBox(height: 8),
          _CartSummaryRow(label: 'Tax', value: Formatters.currency(cart.taxAmount)),
          const Divider(),
          _CartSummaryRow(
            label: 'Total',
            value: Formatters.currency(cart.total),
            isTotal: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Profit: ${Formatters.currency(cart.totalProfit)}',
            style: TextStyle(
              color: cart.totalProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Button(
                  onPressed: cart.isEmpty ? null : () => _showDiscountDialog(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Discount'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: cart.isEmpty || checkoutState.isProcessing
                      ? null
                      : () => _showPaymentDialog(cart),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: checkoutState.isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.money, size: 16),
                              SizedBox(width: 8),
                              Text('Pay'),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBarcodeSearch(String barcode) {
    if (barcode.isEmpty) return;

    final productsAsync = ref.read(productsProvider);
    productsAsync.whenData((products) {
      final product = products.where((p) =>
          p.barcode == barcode || p.code == barcode).firstOrNull;

      if (product != null) {
        _addProductToCart(product);
        _searchController.clear();
        ref.read(_searchQueryProvider.notifier).state = '';
      }
    });
  }

  void _addProductToCart(Product product) {
    if (product.requiresSerial) {
      // For serialized products, add to cart then show serial selection
      ref.read(cartProvider.notifier).addProduct(
            productId: product.id,
            productName: product.name,
            productCode: product.code,
            unitPrice: product.sellingPrice,
            unitCost: product.weightedAvgCost,
            trackSerials: true,
          );

      // Find the cart item and show serial selection
      final cart = ref.read(cartProvider);
      final item = cart.items.firstWhere((i) => i.productId == product.id);
      _showSerialSelectionDialog(item);
    } else {
      ref.read(cartProvider.notifier).addProduct(
            productId: product.id,
            productName: product.name,
            productCode: product.code,
            unitPrice: product.sellingPrice,
            unitCost: product.weightedAvgCost,
            trackSerials: false,
          );
    }
  }

  void _showSerialSelectionDialog(CartItemState item) {
    showDialog(
      context: context,
      builder: (context) => _SerialSelectionDialog(
        productId: item.productId,
        productName: item.productName,
        selectedSerials: item.selectedSerials,
        onSerialAdded: (serial) {
          ref.read(cartProvider.notifier).addSerial(item.productId, serial);
        },
        onSerialRemoved: (serialId) {
          ref.read(cartProvider.notifier).removeSerial(item.productId, serialId);
        },
      ),
    );
  }

  void _showDiscountDialog() {
    final cart = ref.read(cartProvider);
    final controller = TextEditingController(text: cart.discountAmount.toString());

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Apply Discount'),
        content: InfoLabel(
          label: 'Discount Amount',
          child: TextBox(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '0.00',
          ),
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Apply'),
            onPressed: () {
              final discount = double.tryParse(controller.text) ?? 0;
              ref.read(cartProvider.notifier).setDiscount(discount);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(CartState cart) {
    showDialog(
      context: context,
      builder: (context) => _PaymentDialog(
        totalAmount: cart.total,
        isCredit: cart.isCredit,
        onComplete: (payments) {
          ref.read(checkoutProvider.notifier).completeSale(
                payments: payments,
              );
        },
      ),
    );
  }

  void _showSuccessDialog(Sale sale) {
    final cartState = ref.read(cartProvider);
    final customerName = cartState.customerName;

    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Sale Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(FluentIcons.completed_solid, size: 48, color: AppTheme.successColor),
            const SizedBox(height: 16),
            Text('Invoice: ${sale.invoiceNumber}'),
            Text('Total: ${Formatters.currency(sale.totalAmount)}'),
            if (sale.isCredit)
              Text('Payment: Credit Sale', style: TextStyle(color: AppTheme.warningColor)),
          ],
        ),
        actions: [
          Button(
            child: const Text('Print Receipt'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _printReceipt(sale.id, customerName);
            },
          ),
          FilledButton(
            child: const Text('Done'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(String saleId, String? customerName) async {
    try {
      final companySettings = await ref.read(companySettingsProvider.future);
      final db = ref.read(databaseProvider);

      // Fetch full sale details
      final saleDetail = await db.salesDao.getSaleDetail(saleId);
      if (saleDetail == null) {
        throw Exception('Sale not found');
      }

      // Convert to domain entity Sale with items
      final entitySale = entity.Sale(
        id: saleDetail.sale.id,
        invoiceNumber: saleDetail.sale.invoiceNumber,
        customerId: saleDetail.sale.customerId,
        saleDate: saleDetail.sale.saleDate,
        subtotal: saleDetail.sale.subtotal,
        discountAmount: saleDetail.sale.discountAmount,
        taxAmount: saleDetail.sale.taxAmount,
        totalAmount: saleDetail.sale.totalAmount,
        paidAmount: saleDetail.sale.paidAmount,
        totalCost: saleDetail.sale.totalCost,
        grossProfit: saleDetail.sale.grossProfit,
        isCredit: saleDetail.sale.isCredit,
        status: saleDetail.sale.status,
        notes: saleDetail.sale.notes,
        createdBy: saleDetail.sale.createdBy,
        createdAt: saleDetail.sale.createdAt,
        updatedAt: saleDetail.sale.updatedAt,
        items: saleDetail.items.map((item) => entity.SaleItem(
          id: item.item.id,
          saleId: item.item.saleId,
          productId: item.item.productId,
          productName: item.product.name,
          productCode: item.product.code,
          quantity: item.item.quantity,
          unitPrice: item.item.unitPrice,
          unitCost: item.item.unitCost,
          discountAmount: item.item.discountAmount,
          totalPrice: item.item.totalPrice,
          totalCost: item.item.totalCost,
          profit: item.item.profit,
          serials: item.serials.map((s) => entity.SaleSerial(
            id: s.id,
            saleItemId: s.saleItemId,
            serialNumberId: s.serialNumberId,
            serialNumber: s.serialNumber,
            unitCost: s.unitCost,
          )).toList(),
        )).toList(),
      );

      await ReceiptPrinter.printThermalReceipt(
        sale: entitySale,
        companyName: companySettings.name.isNotEmpty ? companySettings.name : 'M-TRONIC',
        companyAddress: companySettings.address.isNotEmpty ? companySettings.address : '',
        companyPhone: companySettings.phone.isNotEmpty ? companySettings.phone : '',
        customerName: customerName ?? saleDetail.customer?.name,
      );
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Print Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }
}

// Product Card
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: Button(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              product.requiresSerial ? FluentIcons.laptop_secure : FluentIcons.product,
              size: 32,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              product.code,
              style: TextStyle(fontSize: 11, color: Colors.grey[100]),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.currency(product.sellingPrice),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Category Chip
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ToggleButton(
        checked: isSelected,
        onChanged: (_) => onPressed(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(label),
        ),
      ),
    );
  }
}

// Cart Item Tile
class _CartItemTile extends StatelessWidget {
  final CartItemState item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback? onSelectSerials;

  const _CartItemTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onSelectSerials,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.productCode,
                      style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 16),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.trackSerials) ...[
                FilledButton(
                  onPressed: onSelectSerials,
                  child: Text('Serials (${item.selectedSerials.length})'),
                ),
              ] else ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.remove, size: 14),
                      onPressed: () => onQuantityChanged(item.quantity - 1),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.add, size: 14),
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                    ),
                  ],
                ),
              ],
              Text(
                Formatters.currency(item.lineTotal),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (item.trackSerials && item.selectedSerials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.selectedSerials.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.serialNumber,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// Cart Summary Row
class _CartSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _CartSummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? FluentTheme.of(context).typography.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  )
              : FluentTheme.of(context).typography.body,
        ),
        Text(
          value,
          style: isTotal
              ? FluentTheme.of(context).typography.subtitle?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  )
              : FluentTheme.of(context).typography.body,
        ),
      ],
    );
  }
}

// Serial Selection Dialog
class _SerialSelectionDialog extends ConsumerWidget {
  final String productId;
  final String productName;
  final List<SelectedSerial> selectedSerials;
  final ValueChanged<SelectedSerial> onSerialAdded;
  final ValueChanged<String> onSerialRemoved;

  const _SerialSelectionDialog({
    required this.productId,
    required this.productName,
    required this.selectedSerials,
    required this.onSerialAdded,
    required this.onSerialRemoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableSerialsAsync = ref.watch(availableSerialNumbersProvider(productId));

    return ContentDialog(
      title: Text('Select Serial Numbers - $productName'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedSerials.isNotEmpty) ...[
            Text('Selected (${selectedSerials.length}):',
                 style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSerials.map((s) => Button(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.serialNumber),
                        const SizedBox(width: 4),
                        const Icon(FluentIcons.chrome_close, size: 12),
                      ],
                    ),
                    onPressed: () => onSerialRemoved(s.id),
                  )).toList(),
            ),
            const Divider(),
          ],
          Text('Available:', style: FluentTheme.of(context).typography.bodyStrong),
          const SizedBox(height: 8),
          Expanded(
            child: availableSerialsAsync.when(
              data: (serials) {
                final available = serials.where((s) =>
                    !selectedSerials.any((sel) => sel.id == s.id)).toList();

                if (available.isEmpty) {
                  return const Center(child: Text('No available serial numbers'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final serial = available[index];
                    return ListTile(
                      title: Text(
                        serial.serialNumber,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      subtitle: Text('Cost: ${Formatters.currency(serial.unitCost)}'),
                      trailing: FilledButton(
                        child: const Text('Add'),
                        onPressed: () {
                          onSerialAdded(SelectedSerial(
                            id: serial.id,
                            serialNumber: serial.serialNumber,
                            unitCost: serial.unitCost,
                          ));
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          child: const Text('Done'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// Payment Dialog
class _PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final bool isCredit;
  final ValueChanged<List<PaymentEntry>> onComplete;

  const _PaymentDialog({
    required this.totalAmount,
    required this.isCredit,
    required this.onComplete,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final List<PaymentEntry> _payments = [];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double get totalPaid => _payments.fold(0, (sum, p) => sum + p.amount);
  double get remaining => widget.totalAmount - totalPaid;

  @override
  Widget build(BuildContext context) {
    if (widget.isCredit) {
      return ContentDialog(
        title: const Text('Credit Sale Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoBar(
              title: const Text('Credit Sale'),
              content: Text('Amount: ${Formatters.currency(widget.totalAmount)}'),
              severity: InfoBarSeverity.warning,
            ),
            const SizedBox(height: 16),
            const Text('This amount will be added to the customer\'s credit balance.'),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Confirm Credit Sale'),
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete([]);
            },
          ),
        ],
      );
    }

    return ContentDialog(
      title: const Text('Payment'),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total: ${Formatters.currency(widget.totalAmount)}',
               style: FluentTheme.of(context).typography.subtitle),
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Paid: ${Formatters.currency(totalPaid)}'),
            Text('Remaining: ${Formatters.currency(remaining)}',
                 style: TextStyle(color: remaining > 0 ? AppTheme.errorColor : AppTheme.successColor)),
          ],
          const Divider(),
          if (_payments.isNotEmpty) ...[
            Text('Payments:', style: FluentTheme.of(context).typography.bodyStrong),
            ...List.generate(_payments.length, (i) {
              final p = _payments[i];
              return ListTile(
                title: Text(p.method.displayName),
                subtitle: p.reference != null ? Text(p.reference!) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Formatters.currency(p.amount)),
                    IconButton(
                      icon: const Icon(FluentIcons.delete, size: 14),
                      onPressed: () {
                        setState(() => _payments.removeAt(i));
                      },
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
          ],
          InfoLabel(
            label: 'Payment Method',
            child: ComboBox<PaymentMethod>(
              value: _selectedMethod,
              items: PaymentMethod.values.map((m) => ComboBoxItem(
                    value: m,
                    child: Text(m.displayName),
                  )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMethod = value);
                }
              },
              isExpanded: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InfoLabel(
                  label: 'Amount',
                  child: TextBox(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              if (_selectedMethod != PaymentMethod.cash) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'Reference',
                    child: TextBox(
                      controller: _referenceController,
                      placeholder: 'Card/Bank ref',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Button(
              child: const Text('Add Payment'),
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0;
                if (amount > 0) {
                  setState(() {
                    _payments.add(PaymentEntry(
                      method: _selectedMethod,
                      amount: amount,
                      reference: _referenceController.text.isEmpty
                          ? null
                          : _referenceController.text,
                    ));
                    _amountController.text = remaining > amount
                        ? (remaining - amount).toStringAsFixed(2)
                        : '0.00';
                    _referenceController.clear();
                  });
                }
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: _payments.isEmpty || remaining > 0.01 ? null : () {
            Navigator.pop(context);
            widget.onComplete(_payments);
          },
          child: const Text('Complete Sale'),
        ),
      ],
    );
  }
}
