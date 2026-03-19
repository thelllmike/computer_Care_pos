import 'package:fluent_ui/fluent_ui.dart';

class OrderStatusChip extends StatelessWidget {
  final String status;

  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _labelForStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _colorForStatus(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFFF8C00);
      case 'CONFIRMED':
        return const Color(0xFF0078D4);
      case 'PACKED':
        return const Color(0xFF8764B8);
      case 'SHIPPED':
        return const Color(0xFF4169E1);
      case 'DELIVERED':
        return const Color(0xFF107C10);
      case 'CANCELLED':
        return const Color(0xFFD13438);
      case 'RETURNED':
        return const Color(0xFF8B4513);
      default:
        return const Color(0xFF605E5C);
    }
  }

  static String _labelForStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PACKED':
        return 'Packed';
      case 'SHIPPED':
        return 'Shipped';
      case 'DELIVERED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      case 'RETURNED':
        return 'Returned';
      default:
        return status;
    }
  }
}
