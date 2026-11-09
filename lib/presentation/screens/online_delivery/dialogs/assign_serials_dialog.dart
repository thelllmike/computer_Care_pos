import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/online_order_model.dart';
import '../../../providers/online_delivery/online_delivery_provider.dart';

class AssignSerialsDialog extends ConsumerStatefulWidget {
  final OnlineOrderModel order;
  final OnlineOrderItemModel item;

  const AssignSerialsDialog({
    super.key,
    required this.order,
    required this.item,
  });

  @override
  ConsumerState<AssignSerialsDialog> createState() =>
      _AssignSerialsDialogState();
}

class _AssignSerialsDialogState
    extends ConsumerState<AssignSerialsDialog> {
  List<Map<String, dynamic>> _availableSerials = [];
  bool _isLoading = true;
  String? _error;

  // Currently assigned serials (serial_number_id → serial info)
  final Map<String, Map<String, dynamic>> _assigned = {};

  @override
  void initState() {
    super.initState();
    // Pre-populate from already-assigned serials
    for (final s in widget.item.serials) {
      _assigned[s.serialNumberId] = {
        'serial_number_id': s.serialNumberId,
        'serial_number': s.serialNumber,
        'unit_cost': s.unitCost.toString(),
      };
    }
    _loadAvailableSerials();
  }

  Future<void> _loadAvailableSerials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = ref.read(onlineDeliveryServiceProvider);
      final serials =
          await service.fetchAvailableSerials(widget.item.productId);
      if (mounted) {
        setState(() {
          _availableSerials = serials;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSerial(Map<String, dynamic> serial) {
    final id = serial['id'] as String;
    setState(() {
      if (_assigned.containsKey(id)) {
        _assigned.remove(id);
      } else {
        if (_assigned.length >= widget.item.quantity) {
          // At capacity — remove oldest entry first (FIFO)
          final firstKey = _assigned.keys.first;
          _assigned.remove(firstKey);
        }
        _assigned[id] = {
          'serial_number_id': id,
          'serial_number': serial['serial_number'] as String,
          'unit_cost':
              (serial['cost_price'] as num?)?.toString() ?? '0',
        };
      }
    });
  }

  Future<void> _save() async {
    final serials = _assigned.values
        .map((s) => Map<String, String>.from(
            s.map((k, v) => MapEntry(k, v.toString()))))
        .toList();

    await ref.read(onlineOrderActionProvider.notifier).assignSerials(
          widget.order.id,
          widget.item.id,
          serials,
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
            content: const Text('Serials assigned successfully.'),
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
        ref.read(onlineOrderActionProvider.notifier).reset();
      }
    });

    final productName =
        widget.item.productName ?? widget.item.productId;
    final required = widget.item.quantity;
    final assignedCount = _assigned.length;
    final isFull = assignedCount >= required;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 560),
      title: Text('Assign Serials — $productName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assignment progress
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFull
                      ? const Color(0xFF107C10).withValues(alpha: 0.1)
                      : const Color(0xFFFF8C00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Assigned: $assignedCount / $required',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isFull
                        ? const Color(0xFF107C10)
                        : const Color(0xFFFF8C00),
                  ),
                ),
              ),
              const Spacer(),
              if (!isFull)
                Text(
                  'Select ${required - assignedCount} more serial(s)',
                  style: const TextStyle(
                      color: Color(0xFFFF8C00), fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Currently assigned
          if (_assigned.isNotEmpty) ...[
            Text('Assigned Serials',
                style:
                    FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 6),
            ..._assigned.values.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.check_mark,
                          size: 14, color: Color(0xFF107C10)),
                      const SizedBox(width: 6),
                      Text(s['serial_number'] as String),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(FluentIcons.cancel,
                            size: 12),
                        onPressed: () {
                          setState(() => _assigned
                              .remove(s['serial_number_id']));
                        },
                      ),
                    ],
                  ),
                )),
            const Divider(),
          ],

          // Available serials
          Text('Available Serials (IN_STOCK)',
              style: FluentTheme.of(context).typography.bodyStrong),
          const SizedBox(height: 6),
          if (_isLoading)
            const Center(child: ProgressRing())
          else if (_error != null)
            InfoBar(
              title: const Text('Error'),
              content: Text(_error!),
              severity: InfoBarSeverity.error,
            )
          else if (_availableSerials.isEmpty)
            const Text('No serials available in stock for this product.')
          else
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: _availableSerials.length,
                itemBuilder: (context, index) {
                  final s = _availableSerials[index];
                  final sId = s['id'] as String;
                  final isSelected = _assigned.containsKey(sId);
                  return ListTile.selectable(
                    leading: isSelected
                        ? const Icon(FluentIcons.check_mark,
                            size: 16, color: Color(0xFF0078D4))
                        : const Icon(FluentIcons.radio_bullet,
                            size: 16,
                            color: Color(0xFF605E5C)),
                    title: Text(s['serial_number'] as String),
                    subtitle: (s['cost_price'] != null)
                        ? Text(
                            'Cost: LKR ${(s['cost_price'] as num).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    selected: isSelected,
                    onPressed: () => _toggleSerial(s),
                  );
                },
              ),
            ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: (actionState.isLoading || assignedCount == 0)
              ? null
              : _save,
          child: actionState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Save Serials'),
        ),
      ],
    );
  }
}
