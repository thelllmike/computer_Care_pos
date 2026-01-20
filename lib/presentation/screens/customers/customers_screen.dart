import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/inventory/customer_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _showCreditOnlyProvider = StateProvider<bool>((ref) => false);

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final showCreditOnly = ref.watch(_showCreditOnlyProvider);
    final customersAsync = ref.watch(customersProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Customers'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Customer'),
              onPressed: () => _showCustomerDialog(context, ref),
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
                    placeholder: 'Search customers...',
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
                Checkbox(
                  checked: showCreditOnly,
                  content: const Text('Credit Customers Only'),
                  onChanged: (value) {
                    ref.read(_showCreditOnlyProvider.notifier).state = value ?? false;
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Customers table
            Expanded(
              child: customersAsync.when(
                data: (customers) {
                  var filtered = customers;
                  if (searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    filtered = filtered.where((c) =>
                        c.name.toLowerCase().contains(query) ||
                        c.code.toLowerCase().contains(query) ||
                        (c.phone?.toLowerCase().contains(query) ?? false) ||
                        (c.email?.toLowerCase().contains(query) ?? false)).toList();
                  }
                  if (showCreditOnly) {
                    filtered = filtered.where((c) => c.creditEnabled).toList();
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  return _buildCustomersTable(context, ref, filtered);
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
            Icon(FluentIcons.people, size: 48, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('No customers found', style: TextStyle(color: Colors.grey[100])),
            const SizedBox(height: 8),
            FilledButton(
              child: const Text('Add First Customer'),
              onPressed: () => _showCustomerDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersTable(BuildContext context, WidgetRef ref, List<Customer> customers) {
    return Card(
      child: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];

          return ListTile.selectable(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: customer.creditEnabled
                    ? AppTheme.warningColor.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FluentIcons.contact,
                color: customer.creditEnabled ? AppTheme.warningColor : AppTheme.primaryColor,
              ),
            ),
            title: Row(
              children: [
                Text(customer.name),
                if (customer.creditEnabled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Credit',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${customer.code}${customer.phone != null ? ' | ${customer.phone}' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customer.creditEnabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Outstanding: ${Formatters.currency(customer.creditBalance)}',
                        style: TextStyle(
                          color: customer.creditBalance > 0 ? AppTheme.errorColor : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Limit: ${Formatters.currency(customer.creditLimit)}',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.edit),
                  onPressed: () => _showCustomerDialog(context, ref, customer: customer),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () => _confirmDelete(context, ref, customer),
                ),
              ],
            ),
            onPressed: () => _showCustomerDialog(context, ref, customer: customer),
          );
        },
      ),
    );
  }

  void _showCustomerDialog(BuildContext context, WidgetRef ref, {Customer? customer}) {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(customer: customer),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${customer.name}"?'),
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
              ref.read(customerFormProvider.notifier).deleteCustomer(customer.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _nicController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _notesController;

  bool _creditEnabled = false;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _nicController = TextEditingController(text: c?.nic ?? '');
    _creditLimitController = TextEditingController(text: c?.creditLimit.toString() ?? '0');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _creditEnabled = c?.creditEnabled ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nicController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(customerFormProvider);

    ref.listen<CustomerFormState>(customerFormProvider, (previous, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
        ref.read(customerFormProvider.notifier).reset();
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
      title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
      constraints: const BoxConstraints(maxWidth: 500),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Customer Name *',
              child: TextBox(
                controller: _nameController,
                placeholder: 'Enter customer name',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Phone',
                    child: TextBox(
                      controller: _phoneController,
                      placeholder: 'Enter phone number',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Email',
                    child: TextBox(
                      controller: _emailController,
                      placeholder: 'Enter email',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'NIC / ID Number',
              child: TextBox(
                controller: _nicController,
                placeholder: 'Enter NIC or ID number',
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
            const Divider(),
            const SizedBox(height: 16),
            Text('Credit Settings', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 12),
            Checkbox(
              checked: _creditEnabled,
              content: const Text('Enable Credit Sales'),
              onChanged: (value) => setState(() => _creditEnabled = value ?? false),
            ),
            if (_creditEnabled) ...[
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Credit Limit',
                child: TextBox(
                  controller: _creditLimitController,
                  placeholder: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ),
              if (isEditing && widget.customer!.creditBalance > 0) ...[
                const SizedBox(height: 8),
                InfoBar(
                  title: const Text('Outstanding Balance'),
                  content: Text(Formatters.currency(widget.customer!.creditBalance)),
                  severity: InfoBarSeverity.warning,
                ),
              ],
            ],
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
          content: Text('Customer name is required'),
          severity: InfoBarSeverity.warning,
        );
      });
      return;
    }

    final creditLimit = double.tryParse(_creditLimitController.text) ?? 0;

    if (isEditing) {
      ref.read(customerFormProvider.notifier).updateCustomer(
            id: widget.customer!.id,
            name: _nameController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            nic: _nicController.text.trim().isEmpty ? null : _nicController.text.trim(),
            creditEnabled: _creditEnabled,
            creditLimit: creditLimit,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
    } else {
      ref.read(customerFormProvider.notifier).createCustomer(
            name: _nameController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            nic: _nicController.text.trim().isEmpty ? null : _nicController.text.trim(),
            creditEnabled: _creditEnabled,
            creditLimit: creditLimit,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
    }
  }
}
