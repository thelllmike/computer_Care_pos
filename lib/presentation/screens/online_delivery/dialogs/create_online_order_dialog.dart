import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../providers/online_delivery/online_delivery_provider.dart';

class CreateOnlineOrderDialog extends ConsumerStatefulWidget {
  const CreateOnlineOrderDialog({super.key});

  @override
  ConsumerState<CreateOnlineOrderDialog> createState() =>
      _CreateOnlineOrderDialogState();
}

class _CreateOnlineOrderDialogState
    extends ConsumerState<CreateOnlineOrderDialog> {
  // Customer fields
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  String? _selectedCustomerId;

  // Order fields
  final _notesController = TextEditingController();
  final _deliveryFeeController = TextEditingController(text: '0');
  String _paymentMethod = 'CASH';
  bool _isPrepaid = false;

  // Product search
  final _productSearchController = TextEditingController();
  List<Map<String, dynamic>> _productResults = [];
  bool _isSearchingProducts = false;

  // Customer search
  final _customerSearchController = TextEditingController();
  List<Map<String, dynamic>> _customerResults = [];
  bool _isSearchingCustomers = false;

  // Line items
  final List<_OrderLineItem> _lineItems = [];

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    _deliveryFeeController.dispose();
    _productSearchController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  // ── Computed totals ──────────────────────────────────────────
  double get _subtotal =>
      _lineItems.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _totalCost =>
      _lineItems.fold(0.0, (sum, i) => sum + i.totalCost);
  double get _grossProfit => _subtotal - _totalCost;
  double get _deliveryFee =>
      double.tryParse(_deliveryFeeController.text) ?? 0.0;
  double get _totalAmount => _subtotal + _deliveryFee;

  bool get _isFormValid =>
      _customerAddressController.text.isNotEmpty && _lineItems.isNotEmpty;

  // ── Customer search ──────────────────────────────────────────
  Future<void> _searchCustomers(String query) async {
    if (query.length < 2) {
      setState(() => _customerResults = []);
      return;
    }
    setState(() => _isSearchingCustomers = true);
    try {
      final service = ref.read(onlineDeliveryServiceProvider);
      final results = await service.searchCustomers(query);
      if (mounted) setState(() => _customerResults = results);
    } finally {
      if (mounted) setState(() => _isSearchingCustomers = false);
    }
  }

  void _selectCustomer(Map<String, dynamic> c) {
    setState(() {
      _selectedCustomerId = c['id'] as String;
      _customerNameController.text = c['name'] as String? ?? '';
      _customerPhoneController.text = c['phone'] as String? ?? '';
      _customerSearchController.clear();
      _customerResults = [];
    });
  }

  // ── Product dropdown subtitle ────────────────────────────────
  String _productSubtitle(Map<String, dynamic> p) {
    final parts = <String>[];
    final code = p['code'] as String?;
    final brand = p['brand'] as String?;
    final model = p['model'] as String?;
    final price = (p['selling_price'] as num?)?.toStringAsFixed(2) ?? '0.00';
    if (code != null && code.isNotEmpty) parts.add(code);
    if (brand != null && brand.isNotEmpty) parts.add(brand);
    if (model != null && model.isNotEmpty) parts.add(model);
    final meta = parts.isNotEmpty ? '${parts.join(' · ')} — ' : '';
    return '${meta}LKR $price';
  }

  // ── Product search ───────────────────────────────────────────
  Future<void> _searchProducts(String query) async {
    if (query.length < 2) {
      setState(() => _productResults = []);
      return;
    }
    setState(() => _isSearchingProducts = true);
    try {
      final service = ref.read(onlineDeliveryServiceProvider);
      final results = await service.searchProducts(query);
      if (mounted) setState(() => _productResults = results);
    } finally {
      if (mounted) setState(() => _isSearchingProducts = false);
    }
  }

  void _addProduct(Map<String, dynamic> product) {
    final existing = _lineItems.indexWhere(
        (i) => i.productId == product['id']);
    setState(() {
      if (existing >= 0) {
        _lineItems[existing] = _lineItems[existing]
            .copyWith(quantity: _lineItems[existing].quantity + 1);
      } else {
        _lineItems.add(_OrderLineItem(
          productId: product['id'] as String,
          productName: product['name'] as String,
          requiresSerial: (product['requires_serial'] as bool?) ?? false,
          quantity: 1,
          unitPrice: (product['selling_price'] as num?)?.toDouble() ?? 0.0,
          unitCost: (product['weighted_avg_cost'] as num?)?.toDouble() ?? 0.0,
        ));
      }
      _productSearchController.clear();
      _productResults = [];
    });
  }

  void _removeItem(int index) {
    setState(() => _lineItems.removeAt(index));
  }

  void _updateQuantity(int index, int qty) {
    if (qty < 1) return;
    setState(() {
      _lineItems[index] = _lineItems[index].copyWith(quantity: qty);
    });
  }

  void _updateUnitPrice(int index, double price) {
    setState(() {
      _lineItems[index] = _lineItems[index].copyWith(unitPrice: price);
    });
  }

  // ── Submit ───────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_isFormValid) return;

    final formState = ref.read(onlineOrderActionProvider);
    if (formState.isLoading) return;

    final itemsData = _lineItems
        .map((i) => {
              'product_id': i.productId,
              'quantity': i.quantity,
              'unit_price': i.unitPrice,
              'unit_cost': i.unitCost,
              'discount_amount': 0.0,
              'total_price': i.totalPrice,
              'total_cost': i.totalCost,
              'profit': i.totalPrice - i.totalCost,
            })
        .toList();

    await ref.read(onlineOrderActionProvider.notifier).createOrder(
          customerId: _selectedCustomerId,
          customerName: _customerNameController.text.isEmpty
              ? null
              : _customerNameController.text,
          customerPhone: _customerPhoneController.text.isEmpty
              ? null
              : _customerPhoneController.text,
          customerAddress: _customerAddressController.text,
          subtotal: _subtotal,
          discountAmount: 0.0,
          taxAmount: 0.0,
          totalAmount: _totalAmount,
          totalCost: _totalCost,
          grossProfit: _grossProfit,
          deliveryFee: _deliveryFee,
          isPrepaid: _isPrepaid,
          paidAmount: _isPrepaid ? _totalAmount : 0.0,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          itemsData: itemsData,
        );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(onlineOrderActionProvider);

    ref.listen<OnlineOrderActionState>(onlineOrderActionProvider,
        (prev, next) {
      if (next.isSuccess && !(prev?.isSuccess ?? false)) {
        Navigator.of(context).pop();
        displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('Success'),
            content: const Text('Online order created successfully.'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
        ref.read(onlineOrderActionProvider.notifier).reset();
      }
      if (next.error != null && prev?.error == null) {
        displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(next.error!),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    });

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 760),
      title: const Text('New Online Order'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer Section ─────────────────────────────────
            Text('Customer',
                style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer search autocomplete
                    InfoLabel(
                      label: 'Search Existing Customer',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextBox(
                            controller: _customerSearchController,
                            placeholder: 'Type name or phone...',
                            onChanged: _searchCustomers,
                          ),
                          if (_isSearchingCustomers)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: ProgressRing(strokeWidth: 2)),
                            ),
                          if (_customerResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: _customerResults
                                    .map((c) => ListTile.selectable(
                                          title: Text(
                                              c['name'] as String? ?? ''),
                                          subtitle: Text(
                                              c['phone'] as String? ?? ''),
                                          onPressed: () => _selectCustomer(c),
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InfoLabel(
                            label: 'Customer Name',
                            child: TextBox(
                              controller: _customerNameController,
                              placeholder: 'Full name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InfoLabel(
                            label: 'Phone',
                            child: TextBox(
                              controller: _customerPhoneController,
                              placeholder: '07X-XXXXXXX',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: 'Delivery Address *',
                      child: TextBox(
                        controller: _customerAddressController,
                        placeholder: 'Full delivery address',
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Items Section ────────────────────────────────────
            Text('Order Items',
                style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product search
                    InfoLabel(
                      label: 'Add Product',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextBox(
                            controller: _productSearchController,
                            placeholder: 'Search by name or code...',
                            onChanged: _searchProducts,
                          ),
                          if (_isSearchingProducts)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: ProgressRing(strokeWidth: 2)),
                            ),
                          if (_productResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: _productResults
                                    .map((p) => ListTile.selectable(
                                          title:
                                              Text(p['name'] as String? ?? ''),
                                          subtitle: Text(
                                            _productSubtitle(p),
                                          ),
                                          trailing: (p['requires_serial'] as bool?) == true
                                              ? Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF8764B8)
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: const Text(
                                                    'Serial',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Color(0xFF8764B8)),
                                                  ),
                                                )
                                              : null,
                                          onPressed: () => _addProduct(p),
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Line items table
                    if (_lineItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No items added yet. Search for products above.',
                            style: TextStyle(color: Color(0xFF605E5C)),
                          ),
                        ),
                      )
                    else ...[
                      // Header
                      const Row(
                        children: [
                          Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 32),
                        ],
                      ),
                      const Divider(),
                      ..._lineItems.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        return _LineItemRow(
                          item: item,
                          onRemove: () => _removeItem(idx),
                          onQuantityChanged: (q) =>
                              _updateQuantity(idx, q),
                          onPriceChanged: (p) =>
                              _updateUnitPrice(idx, p),
                        );
                      }),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                'Subtotal: ${Formatters.currency(_subtotal)}'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Payment & Delivery Section ───────────────────────
            Text('Payment & Delivery',
                style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InfoLabel(
                            label: 'Payment Method *',
                            child: ComboBox<String>(
                              value: _paymentMethod,
                              isExpanded: true,
                              items: const [
                                ComboBoxItem(
                                    value: 'CASH', child: Text('Cash')),
                                ComboBoxItem(
                                    value: 'BANK',
                                    child: Text('Bank Transfer')),
                                ComboBoxItem(
                                    value: 'CARD', child: Text('Card')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _paymentMethod = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InfoLabel(
                            label: 'Delivery Fee',
                            child: TextBox(
                              controller: _deliveryFeeController,
                              placeholder: '0.00',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          checked: _isPrepaid,
                          onChanged: (v) =>
                              setState(() => _isPrepaid = v ?? false),
                          content: const Text('Order is prepaid'),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_deliveryFee > 0)
                              Text(
                                  'Delivery: ${Formatters.currency(_deliveryFee)}'),
                            Text(
                              'Total: ${Formatters.currency(_totalAmount)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ────────────────────────────────────────────
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Order notes or special instructions',
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: (actionState.isLoading || !_isFormValid)
              ? null
              : _submit,
          child: actionState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Create Order'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Line item model (local to this dialog)
// ──────────────────────────────────────────────────────────────
class _OrderLineItem {
  final String productId;
  final String productName;
  final bool requiresSerial;
  final int quantity;
  final double unitPrice;
  final double unitCost;

  const _OrderLineItem({
    required this.productId,
    required this.productName,
    required this.requiresSerial,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  double get totalPrice => quantity * unitPrice;
  double get totalCost => quantity * unitCost;

  _OrderLineItem copyWith({int? quantity, double? unitPrice}) {
    return _OrderLineItem(
      productId: productId,
      productName: productName,
      requiresSerial: requiresSerial,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Line item row widget
// ──────────────────────────────────────────────────────────────
class _LineItemRow extends StatefulWidget {
  final _OrderLineItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double> onPriceChanged;

  const _LineItemRow({
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onPriceChanged,
  });

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _qtyController =
        TextEditingController(text: widget.item.quantity.toString());
    _priceController =
        TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(_LineItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _qtyController.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.productName),
                if (widget.item.requiresSerial)
                  Text('Requires Serial',
                      style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF8764B8).withValues(alpha: 0.8))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: TextBox(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final qty = int.tryParse(v);
                if (qty != null && qty > 0) {
                  widget.onQuantityChanged(qty);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextBox(
              controller: _priceController,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final price = double.tryParse(v);
                if (price != null && price >= 0) {
                  widget.onPriceChanged(price);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              Formatters.currency(widget.item.totalPrice),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(FluentIcons.delete, size: 14),
              onPressed: widget.onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
