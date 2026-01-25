import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/local/tables/expenses_table.dart';
import '../../providers/expenses/expense_provider.dart';
import '../../providers/core/database_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _selectedCategory;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final params = DateRangeParams(startDate: _startDate, endDate: _endDate);
    final summaryAsync = ref.watch(expenseSummaryProvider(params));
    final expensesAsync = ref.watch(expensesByDateRangeProvider(params));

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Expense Management'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Expense'),
              onPressed: () => _showExpenseDialog(context, ref),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(expensesProvider);
                ref.invalidate(expenseSummaryProvider(params));
                ref.invalidate(expensesByDateRangeProvider(params));
              },
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              summaryAsync.when(
                data: (summary) => Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Expenses',
                        value: Formatters.currency(summary.totalAmount),
                        icon: FluentIcons.money,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Expense Count',
                        value: summary.totalExpenses.toString(),
                        icon: FluentIcons.receipt_processing,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Categories',
                        value: summary.categoryBreakdown.length.toString(),
                        icon: FluentIcons.category_classification,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                loading: () => const Row(
                  children: [
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                  ],
                ),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Date filter
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.filter),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            const Text('From: '),
                            DatePicker(
                              selected: _startDate,
                              onChanged: (date) {
                                setState(() => _startDate = date);
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text('To: '),
                            DatePicker(
                              selected: _endDate,
                              onChanged: (date) {
                                setState(() => _endDate = date);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ComboBox<String>(
                        placeholder: const Text('All Categories'),
                        value: _selectedCategory,
                        items: [
                          const ComboBoxItem(value: null, child: Text('All Categories')),
                          ...ExpenseCategory.values.map((c) => ComboBoxItem(
                                value: c.code,
                                child: Text(c.displayName),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Category breakdown
              summaryAsync.when(
                data: (summary) {
                  if (summary.categoryBreakdown.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category Breakdown',
                          style: FluentTheme.of(context).typography.subtitle),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: summary.categoryBreakdown.entries.map((entry) {
                          final category = ExpenseCategory.fromCode(entry.key);
                          final percentage = summary.totalAmount > 0
                              ? (entry.value / summary.totalAmount * 100)
                              : 0.0;
                          return _CategoryChip(
                            category: category.displayName,
                            amount: entry.value,
                            percentage: percentage,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Expenses list
              Text('Expenses', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 12),
              expensesAsync.when(
                data: (expenses) {
                  var filtered = expenses;
                  if (_selectedCategory != null) {
                    filtered = expenses.where((e) => e.category == _selectedCategory).toList();
                  }

                  if (filtered.isEmpty) {
                    return Card(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.money, size: 48, color: Colors.grey[100]),
                              const SizedBox(height: 16),
                              Text('No expenses found', style: TextStyle(color: Colors.grey[100])),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Column(
                      children: filtered.map((expense) => _ExpenseTile(
                            expense: expense,
                            onTap: () => _showExpenseDialog(context, ref, expense: expense),
                            onDelete: () => _deleteExpense(context, ref, expense.id),
                          )).toList(),
                    ),
                  );
                },
                loading: () => const Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: ProgressRing()),
                  ),
                ),
                error: (e, _) => Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExpenseDialog(BuildContext context, WidgetRef ref, {Expense? expense}) {
    if (expense != null) {
      ref.read(expenseFormProvider.notifier).loadExpense(expense.id);
    } else {
      ref.read(expenseFormProvider.notifier).clear();
    }

    showDialog(
      context: context,
      builder: (context) => _ExpenseFormDialog(expense: expense),
    );
  }

  void _deleteExpense(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(AppTheme.errorColor)),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.expenseDao.deleteExpense(id);
      ref.invalidate(expensesProvider);
      ref.invalidate(expenseSummaryProvider(DateRangeParams(startDate: _startDate, endDate: _endDate)));
      ref.invalidate(expensesByDateRangeProvider(DateRangeParams(startDate: _startDate, endDate: _endDate)));
    }
  }
}

// Summary Card Widget
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(color: Colors.grey[100])),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: FluentTheme.of(context).typography.subtitle?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardLoading extends StatelessWidget {
  const _SummaryCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: ProgressRing()),
      ),
    );
  }
}

// Category Chip Widget
class _CategoryChip extends StatelessWidget {
  final String category;
  final double amount;
  final double percentage;

  const _CategoryChip({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(amount),
            style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
        ],
      ),
    );
  }
}

// Expense Tile Widget
class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = ExpenseCategory.fromCode(expense.category);

    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getCategoryIcon(category), color: AppTheme.errorColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            Formatters.currency(expense.amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              category.displayName,
              style: TextStyle(fontSize: 11, color: Colors.grey[120]),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.date(expense.expenseDate),
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
          if (expense.vendor != null) ...[
            const SizedBox(width: 8),
            Text(
              expense.vendor!,
              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.edit, size: 16),
            onPressed: onTap,
          ),
          IconButton(
            icon: Icon(FluentIcons.delete, size: 16, color: AppTheme.errorColor),
            onPressed: onDelete,
          ),
        ],
      ),
      onPressed: onTap,
    );
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.electricity:
        return FluentIcons.lightbulb;
      case ExpenseCategory.water:
        return FluentIcons.drop_shape;
      case ExpenseCategory.rent:
        return FluentIcons.home;
      case ExpenseCategory.internet:
        return FluentIcons.globe;
      case ExpenseCategory.telephone:
        return FluentIcons.phone;
      case ExpenseCategory.salary:
        return FluentIcons.people;
      case ExpenseCategory.supplies:
        return FluentIcons.product;
      case ExpenseCategory.maintenance:
        return FluentIcons.repair;
      case ExpenseCategory.transport:
        return FluentIcons.car;
      case ExpenseCategory.other:
        return FluentIcons.money;
    }
  }
}

// Expense Form Dialog
class _ExpenseFormDialog extends ConsumerStatefulWidget {
  final Expense? expense;

  const _ExpenseFormDialog({this.expense});

  @override
  ConsumerState<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<_ExpenseFormDialog> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toString();
      _vendorController.text = widget.expense!.vendor ?? '';
      _referenceController.text = widget.expense!.referenceNumber ?? '';
      _notesController.text = widget.expense!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(expenseFormProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: Text(widget.expense != null ? 'Edit Expense' : 'Add Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category
            InfoLabel(
              label: 'Category *',
              child: ComboBox<String>(
                value: formState.category,
                items: ExpenseCategory.values.map((c) => ComboBoxItem(
                      value: c.code,
                      child: Text(c.displayName),
                    )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(expenseFormProvider.notifier).setCategory(value);
                  }
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            InfoLabel(
              label: 'Description *',
              child: TextBox(
                controller: _descriptionController,
                placeholder: 'e.g., Monthly electricity bill',
                onChanged: (value) {
                  ref.read(expenseFormProvider.notifier).setDescription(value);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            InfoLabel(
              label: 'Amount *',
              child: TextBox(
                controller: _amountController,
                placeholder: '0.00',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  ref.read(expenseFormProvider.notifier).setAmount(amount);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Date
            InfoLabel(
              label: 'Expense Date *',
              child: DatePicker(
                selected: formState.expenseDate,
                onChanged: (date) {
                  ref.read(expenseFormProvider.notifier).setExpenseDate(date);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Vendor
            InfoLabel(
              label: 'Vendor/Payee',
              child: TextBox(
                controller: _vendorController,
                placeholder: 'e.g., Ceylon Electricity Board',
                onChanged: (value) {
                  ref.read(expenseFormProvider.notifier).setVendor(value.isEmpty ? null : value);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method
            InfoLabel(
              label: 'Payment Method',
              child: ComboBox<String>(
                placeholder: const Text('Select payment method'),
                value: formState.paymentMethod,
                items: const [
                  ComboBoxItem(value: 'CASH', child: Text('Cash')),
                  ComboBoxItem(value: 'BANK', child: Text('Bank Transfer')),
                  ComboBoxItem(value: 'CARD', child: Text('Card')),
                  ComboBoxItem(value: 'CHEQUE', child: Text('Cheque')),
                ],
                onChanged: (value) {
                  ref.read(expenseFormProvider.notifier).setPaymentMethod(value);
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 16),

            // Reference Number
            InfoLabel(
              label: 'Reference/Receipt Number',
              child: TextBox(
                controller: _referenceController,
                placeholder: 'Bill or receipt number',
                onChanged: (value) {
                  ref.read(expenseFormProvider.notifier).setReferenceNumber(value.isEmpty ? null : value);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                maxLines: 2,
                placeholder: 'Additional notes',
                onChanged: (value) {
                  ref.read(expenseFormProvider.notifier).setNotes(value.isEmpty ? null : value);
                },
              ),
            ),

            if (formState.error != null) ...[
              const SizedBox(height: 16),
              InfoBar(
                title: const Text('Error'),
                content: Text(formState.error!),
                severity: InfoBarSeverity.error,
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: formState.isSaving
              ? null
              : () async {
                  final expense = await ref.read(expenseFormProvider.notifier).saveExpense();
                  if (expense != null && mounted) {
                    Navigator.of(context).pop();
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Success'),
                        content: Text('Expense ${expense.expenseNumber} saved'),
                        severity: InfoBarSeverity.success,
                        onClose: close,
                      );
                    });
                  }
                },
          child: formState.isSaving
              ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : Text(widget.expense != null ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
