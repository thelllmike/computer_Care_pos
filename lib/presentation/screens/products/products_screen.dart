import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/product_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/inventory/category_provider.dart';
import '../../providers/inventory/product_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _selectedTypeProvider = StateProvider<ProductType?>((ref) => null);
final _selectedCategoryProvider = StateProvider<String?>((ref) => null);

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final selectedType = ref.watch(_selectedTypeProvider);
    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Products'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Product'),
              onPressed: () => _showProductDialog(context, ref),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and filters
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Search products...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 16),
                    ),
                    onChanged: (value) {
                      ref.read(_searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                categoriesAsync.when(
                  data: (categories) => ComboBox<String?>(
                    value: selectedCategory,
                    placeholder: const Text('All Categories'),
                    items: [
                      const ComboBoxItem(value: null, child: Text('All Categories')),
                      ...categories.map((c) => ComboBoxItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
                    ],
                    onChanged: (value) {
                      ref.read(_selectedCategoryProvider.notifier).state = value;
                    },
                  ),
                  loading: () => const SizedBox(width: 150),
                  error: (_, __) => const SizedBox(width: 150),
                ),
                const SizedBox(width: 16),
                ComboBox<ProductType?>(
                  value: selectedType,
                  placeholder: const Text('All Types'),
                  items: [
                    const ComboBoxItem(value: null, child: Text('All Types')),
                    ...ProductType.values.map((t) => ComboBoxItem(
                          value: t,
                          child: Text(t.displayName),
                        )),
                  ],
                  onChanged: (value) {
                    ref.read(_selectedTypeProvider.notifier).state = value;
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Products table
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  // Apply filters
                  var filtered = products;
                  if (searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    filtered = filtered.where((p) =>
                        p.name.toLowerCase().contains(query) ||
                        p.code.toLowerCase().contains(query) ||
                        (p.barcode?.toLowerCase().contains(query) ?? false) ||
                        (p.brand?.toLowerCase().contains(query) ?? false)).toList();
                  }
                  if (selectedType != null) {
                    filtered = filtered.where((p) => p.productType == selectedType.code).toList();
                  }
                  if (selectedCategory != null) {
                    filtered = filtered.where((p) => p.categoryId == selectedCategory).toList();
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  return _buildProductsTable(context, ref, filtered);
                },
                loading: () => const Center(child: ProgressRing()),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.product, size: 48, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('No products found', style: TextStyle(color: Colors.grey[100])),
            const SizedBox(height: 8),
            FilledButton(
              child: const Text('Add First Product'),
              onPressed: () => _showProductDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTable(BuildContext context, WidgetRef ref, List<Product> products) {
    return Card(
      child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final type = ProductTypeExtension.fromString(product.productType);

          return ListTile.selectable(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                type == ProductType.laptop ? FluentIcons.laptop_secure : FluentIcons.product,
                color: AppTheme.primaryColor,
              ),
            ),
            title: Text(product.name),
            subtitle: Text(
              '${product.code} | ${type.displayName}${product.brand != null ? ' | ${product.brand}' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      Formatters.currency(product.sellingPrice),
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                    Text(
                      'Cost: ${Formatters.currency(product.weightedAvgCost)}',
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.edit),
                  onPressed: () => _showProductDialog(context, ref, product: product),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () => _confirmDelete(context, ref, product),
                ),
              ],
            ),
            onPressed: () => _showProductDialog(context, ref, product: product),
          );
        },
      ),
    );
  }

  void _showProductDialog(BuildContext context, WidgetRef ref, {Product? product}) {
    showDialog(
      context: context,
      builder: (context) => ProductFormDialog(product: product),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Delete'),
            onPressed: () {
              ref.read(productFormProvider.notifier).deleteProduct(product.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _warrantyController;
  late final TextEditingController _reorderLevelController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;

  ProductType _productType = ProductType.accessory;
  bool _requiresSerial = false;
  String? _categoryId;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice.toString() ?? '0');
    _warrantyController = TextEditingController(text: p?.warrantyMonths.toString() ?? '0');
    _reorderLevelController = TextEditingController(text: p?.reorderLevel.toString() ?? '5');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _modelController = TextEditingController(text: p?.model ?? '');

    if (p != null) {
      _productType = ProductTypeExtension.fromString(p.productType);
      _requiresSerial = p.requiresSerial;
      _categoryId = p.categoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _sellingPriceController.dispose();
    _warrantyController.dispose();
    _reorderLevelController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(productFormProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    ref.listen<ProductFormState>(productFormProvider, (previous, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
        ref.read(productFormProvider.notifier).reset();
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

    return ContentDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      constraints: const BoxConstraints(maxWidth: 600),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Product Name *',
                      child: TextBox(
                        controller: _nameController,
                        placeholder: 'Enter product name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Barcode',
                      child: TextBox(
                        controller: _barcodeController,
                        placeholder: 'Enter barcode',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Product Type *',
                      child: ComboBox<ProductType>(
                        value: _productType,
                        isExpanded: true,
                        items: ProductType.values.map((t) => ComboBoxItem(
                              value: t,
                              child: Text(t.displayName),
                            )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _productType = value;
                              if (value == ProductType.laptop) {
                                _requiresSerial = true;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Category',
                      child: categoriesAsync.when(
                        data: (categories) => ComboBox<String?>(
                          value: _categoryId,
                          isExpanded: true,
                          placeholder: const Text('Select category'),
                          items: [
                            const ComboBoxItem(value: null, child: Text('None')),
                            ...categories.map((c) => ComboBoxItem(
                                  value: c.id,
                                  child: Text(c.name),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _categoryId = value);
                          },
                        ),
                        loading: () => const ProgressRing(),
                        error: (_, __) => const Text('Error loading categories'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Brand',
                      child: TextBox(
                        controller: _brandController,
                        placeholder: 'Enter brand',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Model',
                      child: TextBox(
                        controller: _modelController,
                        placeholder: 'Enter model',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Selling Price *',
                      child: TextBox(
                        controller: _sellingPriceController,
                        placeholder: '0.00',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Warranty (months)',
                      child: TextBox(
                        controller: _warrantyController,
                        placeholder: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Reorder Level',
                      child: TextBox(
                        controller: _reorderLevelController,
                        placeholder: '5',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Checkbox(
                checked: _requiresSerial,
                content: const Text('Requires Serial Number'),
                onChanged: _productType == ProductType.laptop
                    ? null
                    : (value) => setState(() => _requiresSerial = value ?? false),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Description',
                child: TextBox(
                  controller: _descriptionController,
                  placeholder: 'Enter description',
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: formState.isLoading ? null : _submit,
          child: formState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      displayInfoBar(context, builder: (context, close) {
        return const InfoBar(
          title: Text('Validation Error'),
          content: Text('Product name is required'),
          severity: InfoBarSeverity.warning,
        );
      });
      return;
    }

    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
    final warrantyMonths = int.tryParse(_warrantyController.text) ?? 0;
    final reorderLevel = int.tryParse(_reorderLevelController.text) ?? 5;

    if (isEditing) {
      ref.read(productFormProvider.notifier).updateProduct(
            id: widget.product!.id,
            name: _nameController.text.trim(),
            barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            categoryId: _categoryId,
            productType: _productType,
            requiresSerial: _requiresSerial,
            sellingPrice: sellingPrice,
            warrantyMonths: warrantyMonths,
            reorderLevel: reorderLevel,
            brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
            model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
          );
    } else {
      ref.read(productFormProvider.notifier).createProduct(
            name: _nameController.text.trim(),
            barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            categoryId: _categoryId,
            productType: _productType,
            requiresSerial: _requiresSerial,
            sellingPrice: sellingPrice,
            warrantyMonths: warrantyMonths,
            reorderLevel: reorderLevel,
            brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
            model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
          );
    }
  }
}
