import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/inventory/supplier_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final suppliersAsync = ref.watch(suppliersProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Suppliers'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Supplier'),
              onPressed: () => _showSupplierDialog(context, ref),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Search suppliers...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 16),
                    ),
                    onChanged: (value) {
                      ref.read(_searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Suppliers table
            Expanded(
              child: suppliersAsync.when(
                data: (suppliers) {
                  var filtered = suppliers;
                  if (searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    filtered = filtered.where((s) =>
                        s.name.toLowerCase().contains(query) ||
                        s.code.toLowerCase().contains(query) ||
                        (s.contactPerson?.toLowerCase().contains(query) ?? false) ||
                        (s.phone?.toLowerCase().contains(query) ?? false)).toList();
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  return _buildSuppliersTable(context, ref, filtered);
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
            Icon(FluentIcons.factory, size: 48, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('No suppliers found', style: TextStyle(color: Colors.grey[100])),
            const SizedBox(height: 8),
            FilledButton(
              child: const Text('Add First Supplier'),
              onPressed: () => _showSupplierDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuppliersTable(BuildContext context, WidgetRef ref, List<Supplier> suppliers) {
    return Card(
      child: ListView.builder(
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final supplier = suppliers[index];

          return ListTile.selectable(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FluentIcons.factory,
                color: AppTheme.primaryColor,
              ),
            ),
            title: Text(supplier.name),
            subtitle: Text(
              '${supplier.code}${supplier.contactPerson != null ? ' | ${supplier.contactPerson}' : ''}${supplier.phone != null ? ' | ${supplier.phone}' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Payment: ${supplier.paymentTermDays} days',
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.edit),
                  onPressed: () => _showSupplierDialog(context, ref, supplier: supplier),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () => _confirmDelete(context, ref, supplier),
                ),
              ],
            ),
            onPressed: () => _showSupplierDialog(context, ref, supplier: supplier),
          );
        },
      ),
    );
  }

  void _showSupplierDialog(BuildContext context, WidgetRef ref, {Supplier? supplier}) {
    showDialog(
      context: context,
      builder: (context) => SupplierFormDialog(supplier: supplier),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Supplier supplier) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete "${supplier.name}"?'),
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
              ref.read(supplierFormProvider.notifier).deleteSupplier(supplier.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class SupplierFormDialog extends ConsumerStatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _paymentTermsController;
  late final TextEditingController _notesController;

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameController = TextEditingController(text: s?.name ?? '');
    _contactPersonController = TextEditingController(text: s?.contactPerson ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _taxIdController = TextEditingController(text: s?.taxId ?? '');
    _paymentTermsController = TextEditingController(text: s?.paymentTermDays.toString() ?? '30');
    _notesController = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(supplierFormProvider);

    ref.listen<SupplierFormState>(supplierFormProvider, (previous, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
        ref.read(supplierFormProvider.notifier).reset();
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
      title: Text(isEditing ? 'Edit Supplier' : 'Add Supplier'),
      constraints: const BoxConstraints(maxWidth: 500),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Supplier Name *',
              child: TextBox(
                controller: _nameController,
                placeholder: 'Enter supplier name',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Contact Person',
                    child: TextBox(
                      controller: _contactPersonController,
                      placeholder: 'Enter contact person',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Phone',
                    child: TextBox(
                      controller: _phoneController,
                      placeholder: 'Enter phone number',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Email',
              child: TextBox(
                controller: _emailController,
                placeholder: 'Enter email',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Address',
              child: TextBox(
                controller: _addressController,
                placeholder: 'Enter address',
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Tax ID',
                    child: TextBox(
                      controller: _taxIdController,
                      placeholder: 'Enter tax ID',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Payment Terms (days)',
                    child: TextBox(
                      controller: _paymentTermsController,
                      placeholder: '30',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Enter notes',
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
          content: Text('Supplier name is required'),
          severity: InfoBarSeverity.warning,
        );
      });
      return;
    }

    final paymentTerms = int.tryParse(_paymentTermsController.text) ?? 30;

    if (isEditing) {
      ref.read(supplierFormProvider.notifier).updateSupplier(
            id: widget.supplier!.id,
            name: _nameController.text.trim(),
            contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
            paymentTermDays: paymentTerms,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
    } else {
      ref.read(supplierFormProvider.notifier).createSupplier(
            name: _nameController.text.trim(),
            contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
            paymentTermDays: paymentTerms,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
    }
  }
}
