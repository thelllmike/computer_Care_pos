import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/serial_status.dart';
import '../database/app_database.dart';
import '../tables/repairs_table.dart';
import '../tables/customers_table.dart';
import '../tables/products_table.dart';
import '../tables/serial_numbers_table.dart';
import '../tables/inventory_table.dart';
import '../tables/sales_table.dart';
import '../tables/credit_transactions_table.dart';

part 'repair_dao.g.dart';

// Repair status enum
enum RepairStatus {
  received,
  diagnosing,
  waitingApproval,
  waitingParts,
  inProgress,
  completed,
  readyForPickup,
  delivered,
  cancelled,
}

extension RepairStatusExtension on RepairStatus {
  String get code {
    switch (this) {
      case RepairStatus.received:
        return 'RECEIVED';
      case RepairStatus.diagnosing:
        return 'DIAGNOSING';
      case RepairStatus.waitingApproval:
        return 'WAITING_APPROVAL';
      case RepairStatus.waitingParts:
        return 'WAITING_PARTS';
      case RepairStatus.inProgress:
        return 'IN_PROGRESS';
      case RepairStatus.completed:
        return 'COMPLETED';
      case RepairStatus.readyForPickup:
        return 'READY_FOR_PICKUP';
      case RepairStatus.delivered:
        return 'DELIVERED';
      case RepairStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get displayName {
    switch (this) {
      case RepairStatus.received:
        return 'Received';
      case RepairStatus.diagnosing:
        return 'Diagnosing';
      case RepairStatus.waitingApproval:
        return 'Waiting Approval';
      case RepairStatus.waitingParts:
        return 'Waiting Parts';
      case RepairStatus.inProgress:
        return 'In Progress';
      case RepairStatus.completed:
        return 'Completed';
      case RepairStatus.readyForPickup:
        return 'Ready for Pickup';
      case RepairStatus.delivered:
        return 'Delivered';
      case RepairStatus.cancelled:
        return 'Cancelled';
    }
  }

  static RepairStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RECEIVED':
        return RepairStatus.received;
      case 'DIAGNOSING':
        return RepairStatus.diagnosing;
      case 'WAITING_APPROVAL':
        return RepairStatus.waitingApproval;
      case 'WAITING_PARTS':
        return RepairStatus.waitingParts;
      case 'IN_PROGRESS':
        return RepairStatus.inProgress;
      case 'COMPLETED':
        return RepairStatus.completed;
      case 'READY_FOR_PICKUP':
        return RepairStatus.readyForPickup;
      case 'DELIVERED':
        return RepairStatus.delivered;
      case 'CANCELLED':
        return RepairStatus.cancelled;
      default:
        return RepairStatus.received;
    }
  }

  // Check if status can transition to another status
  bool canTransitionTo(RepairStatus newStatus) {
    switch (this) {
      case RepairStatus.received:
        return [
          RepairStatus.diagnosing,
          RepairStatus.cancelled,
        ].contains(newStatus);
      case RepairStatus.diagnosing:
        return [
          RepairStatus.waitingApproval,
          RepairStatus.inProgress,
          RepairStatus.cancelled,
        ].contains(newStatus);
      case RepairStatus.waitingApproval:
        return [
          RepairStatus.inProgress,
          RepairStatus.waitingParts,
          RepairStatus.cancelled,
        ].contains(newStatus);
      case RepairStatus.waitingParts:
        return [
          RepairStatus.inProgress,
          RepairStatus.cancelled,
        ].contains(newStatus);
      case RepairStatus.inProgress:
        return [
          RepairStatus.completed,
          RepairStatus.waitingParts,
          RepairStatus.cancelled,
        ].contains(newStatus);
      case RepairStatus.completed:
        return [
          RepairStatus.readyForPickup,
        ].contains(newStatus);
      case RepairStatus.readyForPickup:
        return [
          RepairStatus.delivered,
        ].contains(newStatus);
      case RepairStatus.delivered:
      case RepairStatus.cancelled:
        return false;
    }
  }
}

@DriftAccessor(tables: [
  RepairJobs,
  RepairParts,
  RepairStatusHistory,
  Customers,
  Products,
  SerialNumbers,
  Inventory,
  Sales,
  SaleItems,
  CreditTransactions,
])
class RepairDao extends DatabaseAccessor<AppDatabase> with _$RepairDaoMixin {
  RepairDao(super.db);

  static const _uuid = Uuid();

  // ==================== Repair Job CRUD ====================

  // Get all repair jobs
  Future<List<RepairJobWithCustomer>> getAllRepairJobs() async {
    final query = select(repairJobs).join([
      leftOuterJoin(customers, customers.id.equalsExp(repairJobs.customerId)),
    ])
      ..orderBy([OrderingTerm.desc(repairJobs.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return RepairJobWithCustomer(
        repairJob: row.readTable(repairJobs),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get repair jobs by status
  Future<List<RepairJobWithCustomer>> getRepairJobsByStatus(
      RepairStatus status) async {
    final query = select(repairJobs).join([
      leftOuterJoin(customers, customers.id.equalsExp(repairJobs.customerId)),
    ])
      ..where(repairJobs.status.equals(status.code))
      ..orderBy([OrderingTerm.desc(repairJobs.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return RepairJobWithCustomer(
        repairJob: row.readTable(repairJobs),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get active repair jobs (not delivered or cancelled)
  Future<List<RepairJobWithCustomer>> getActiveRepairJobs() async {
    final query = select(repairJobs).join([
      leftOuterJoin(customers, customers.id.equalsExp(repairJobs.customerId)),
    ])
      ..where(repairJobs.status.isNotIn(['DELIVERED', 'CANCELLED']))
      ..orderBy([OrderingTerm.desc(repairJobs.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return RepairJobWithCustomer(
        repairJob: row.readTable(repairJobs),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get repair job by ID
  Future<RepairJob?> getRepairJobById(String id) {
    return (select(repairJobs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get repair job detail
  Future<RepairJobDetail?> getRepairJobDetail(String id) async {
    final job = await getRepairJobById(id);
    if (job == null) return null;

    final customer = (job.customerId != null && job.customerId!.isNotEmpty)
        ? await (select(customers)..where((c) => c.id.equals(job.customerId!)))
            .getSingleOrNull()
        : null;

    final parts = await getRepairParts(id);
    final history = await getStatusHistory(id);

    // Check warranty if it's our serial
    WarrantyInfo? warrantyInfo;
    if (job.serialNumberId != null) {
      warrantyInfo = await checkWarranty(job.serialNumberId!);
    }

    return RepairJobDetail(
      repairJob: job,
      customer: customer,
      parts: parts,
      statusHistory: history,
      warrantyInfo: warrantyInfo,
    );
  }

  // Create repair job
  Future<RepairJob> createRepairJob({
    String? customerId, // Nullable for manual customers
    String? manualCustomerName, // For walk-in customers
    String? manualCustomerPhone,
    required String deviceType,
    required String problemDescription,
    String? serialNumberId,
    String? deviceBrand,
    String? deviceModel,
    String? deviceSerial,
    double estimatedCost = 0,
    DateTime? promisedDate,
    String? receivedBy,
    String? notes,
  }) async {
    // Validate that either customerId or manualCustomerName is provided
    if (customerId == null && (manualCustomerName == null || manualCustomerName.isEmpty)) {
      throw Exception('Either a customer or manual customer name is required');
    }

    return transaction(() async {
      final jobNumber = await attachedDatabase.getNextSequenceNumber('REPAIR_JOB');
      final jobId = _uuid.v4();

      // Check warranty if it's our serial
      bool isUnderWarranty = false;
      String? warrantyNotes;
      if (serialNumberId != null) {
        final warrantyInfo = await checkWarranty(serialNumberId);
        if (warrantyInfo != null && warrantyInfo.isUnderWarranty) {
          isUnderWarranty = true;
          warrantyNotes =
              'Device under warranty until ${warrantyInfo.warrantyExpiry}';
        }
      }

      final job = RepairJobsCompanion.insert(
        id: jobId,
        jobNumber: jobNumber,
        customerId: Value(customerId),
        manualCustomerName: Value(manualCustomerName),
        manualCustomerPhone: Value(manualCustomerPhone),
        serialNumberId: Value(serialNumberId),
        deviceType: deviceType,
        deviceBrand: Value(deviceBrand),
        deviceModel: Value(deviceModel),
        deviceSerial: Value(deviceSerial),
        problemDescription: problemDescription,
        estimatedCost: Value(estimatedCost),
        promisedDate: Value(promisedDate),
        isUnderWarranty: Value(isUnderWarranty),
        warrantyNotes: Value(warrantyNotes),
        receivedDate: DateTime.now(),
        receivedBy: Value(receivedBy),
        notes: Value(notes),
      );

      await into(repairJobs).insert(job);

      // Record status history
      await _recordStatusChange(
        jobId: jobId,
        fromStatus: null,
        toStatus: RepairStatus.received,
        changedBy: receivedBy,
        notes: 'Job created',
      );

      // If it's our serial, update its status
      if (serialNumberId != null) {
        await (update(serialNumbers)
              ..where((s) => s.id.equals(serialNumberId)))
            .write(SerialNumbersCompanion(
          status: Value(SerialStatus.inRepair.code),
          updatedAt: Value(DateTime.now()),
        ));
      }

      return (await getRepairJobById(jobId))!;
    });
  }

  // Update repair job
  Future<void> updateRepairJob({
    required String id,
    String? diagnosis,
    double? estimatedCost,
    double? laborCost,
    DateTime? promisedDate,
    String? assignedTo,
    String? notes,
  }) async {
    await (update(repairJobs)..where((j) => j.id.equals(id))).write(
      RepairJobsCompanion(
        diagnosis: diagnosis != null ? Value(diagnosis) : const Value.absent(),
        estimatedCost:
            estimatedCost != null ? Value(estimatedCost) : const Value.absent(),
        laborCost: laborCost != null ? Value(laborCost) : const Value.absent(),
        promisedDate:
            promisedDate != null ? Value(promisedDate) : const Value.absent(),
        assignedTo:
            assignedTo != null ? Value(assignedTo) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _updateTotalCost(id);
  }

  // Update repair job status
  Future<bool> updateStatus({
    required String jobId,
    required RepairStatus newStatus,
    String? changedBy,
    String? notes,
  }) async {
    final job = await getRepairJobById(jobId);
    if (job == null) return false;

    final currentStatus = RepairStatusExtension.fromString(job.status);

    // Validate transition
    if (!currentStatus.canTransitionTo(newStatus)) {
      return false;
    }

    return transaction(() async {
      final updateData = RepairJobsCompanion(
        status: Value(newStatus.code),
        updatedAt: Value(DateTime.now()),
      );

      // Set completion/delivery dates
      if (newStatus == RepairStatus.completed) {
        await (update(repairJobs)..where((j) => j.id.equals(jobId))).write(
          RepairJobsCompanion(
            status: Value(newStatus.code),
            completedDate: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else if (newStatus == RepairStatus.delivered) {
        await (update(repairJobs)..where((j) => j.id.equals(jobId))).write(
          RepairJobsCompanion(
            status: Value(newStatus.code),
            deliveredDate: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // If it's our serial, update its status back to sold
        if (job.serialNumberId != null) {
          await (update(serialNumbers)
                ..where((s) => s.id.equals(job.serialNumberId!)))
              .write(SerialNumbersCompanion(
            status: Value(SerialStatus.sold.code),
            updatedAt: Value(DateTime.now()),
          ));
        }
      } else {
        await (update(repairJobs)..where((j) => j.id.equals(jobId)))
            .write(updateData);
      }

      // Record history
      await _recordStatusChange(
        jobId: jobId,
        fromStatus: currentStatus,
        toStatus: newStatus,
        changedBy: changedBy,
        notes: notes,
      );

      return true;
    });
  }

  // ==================== Parts Management ====================

  // Get repair parts
  Future<List<RepairPartWithProduct>> getRepairParts(String repairJobId) async {
    final query = select(repairParts).join([
      leftOuterJoin(products, products.id.equalsExp(repairParts.productId)),
    ])
      ..where(repairParts.repairJobId.equals(repairJobId));

    final results = await query.get();
    return results.map((row) {
      return RepairPartWithProduct(
        part: row.readTable(repairParts),
        product: row.readTableOrNull(products),
      );
    }).toList();
  }

  // Add part to repair job
  Future<RepairPart> addRepairPart({
    required String repairJobId,
    required String productId,
    required int quantity,
    required double unitCost,
    required double unitPrice,
    String? serialNumberId,
  }) async {
    return transaction(() async {
      final partId = _uuid.v4();

      // Deduct from inventory
      final inventoryItem = await (select(inventory)
            ..where((i) => i.productId.equals(productId)))
          .getSingleOrNull();

      if (inventoryItem == null || inventoryItem.quantityOnHand < quantity) {
        throw Exception('Insufficient inventory for this part');
      }

      // Update inventory
      await (update(inventory)..where((i) => i.productId.equals(productId)))
          .write(InventoryCompanion(
        quantityOnHand: Value(inventoryItem.quantityOnHand - quantity),
        totalCost:
            Value(inventoryItem.totalCost - (unitCost * quantity)),
        updatedAt: Value(DateTime.now()),
      ));

      // If serialized part, update serial status
      if (serialNumberId != null) {
        await (update(serialNumbers)
              ..where((s) => s.id.equals(serialNumberId)))
            .write(SerialNumbersCompanion(
          status: Value(SerialStatus.sold.code),
          updatedAt: Value(DateTime.now()),
        ));
      }

      // Insert repair part
      final part = RepairPartsCompanion.insert(
        id: partId,
        repairJobId: repairJobId,
        productId: productId,
        serialNumberId: Value(serialNumberId),
        quantity: quantity,
        unitCost: unitCost,
        unitPrice: unitPrice,
        totalCost: unitCost * quantity,
        totalPrice: unitPrice * quantity,
      );

      await into(repairParts).insert(part);

      // Update repair job parts cost
      await _updateTotalCost(repairJobId);

      return (await (select(repairParts)..where((p) => p.id.equals(partId)))
          .getSingle());
    });
  }

  // Remove part from repair job
  Future<void> removeRepairPart(String partId) async {
    return transaction(() async {
      final part = await (select(repairParts)..where((p) => p.id.equals(partId)))
          .getSingleOrNull();
      if (part == null) return;

      // Return to inventory
      final inventoryItem = await (select(inventory)
            ..where((i) => i.productId.equals(part.productId)))
          .getSingleOrNull();

      if (inventoryItem != null) {
        await (update(inventory)
              ..where((i) => i.productId.equals(part.productId)))
            .write(InventoryCompanion(
          quantityOnHand: Value(inventoryItem.quantityOnHand + part.quantity),
          totalCost: Value(inventoryItem.totalCost + part.totalCost),
          updatedAt: Value(DateTime.now()),
        ));
      }

      // If serialized, update serial status back
      if (part.serialNumberId != null) {
        await (update(serialNumbers)
              ..where((s) => s.id.equals(part.serialNumberId!)))
            .write(SerialNumbersCompanion(
          status: Value(SerialStatus.inStock.code),
          updatedAt: Value(DateTime.now()),
        ));
      }

      // Delete the part
      await (delete(repairParts)..where((p) => p.id.equals(partId))).go();

      // Update repair job costs
      await _updateTotalCost(part.repairJobId);
    });
  }

  // Update total cost of repair job
  Future<void> _updateTotalCost(String repairJobId) async {
    final job = await getRepairJobById(repairJobId);
    if (job == null) return;

    final parts = await getRepairParts(repairJobId);
    double partsCost = 0;
    for (final part in parts) {
      partsCost += part.part.totalPrice;
    }

    final totalCost = job.laborCost + partsCost;

    await (update(repairJobs)..where((j) => j.id.equals(repairJobId))).write(
      RepairJobsCompanion(
        partsCost: Value(partsCost),
        totalCost: Value(totalCost),
        actualCost: Value(totalCost),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== Status History ====================

  Future<List<RepairStatusHistoryData>> getStatusHistory(String repairJobId) async {
    return (select(repairStatusHistory)
          ..where((h) => h.repairJobId.equals(repairJobId))
          ..orderBy([(h) => OrderingTerm.desc(h.changedAt)]))
        .get();
  }

  Future<void> _recordStatusChange({
    required String jobId,
    RepairStatus? fromStatus,
    required RepairStatus toStatus,
    String? changedBy,
    String? notes,
  }) async {
    final historyId = _uuid.v4();
    await into(repairStatusHistory).insert(
      RepairStatusHistoryCompanion.insert(
        id: historyId,
        repairJobId: jobId,
        fromStatus: Value(fromStatus?.code),
        toStatus: toStatus.code,
        notes: Value(notes),
        changedBy: Value(changedBy),
      ),
    );
  }

  // ==================== Warranty Check ====================

  Future<WarrantyInfo?> checkWarranty(String serialNumberId) async {
    final serial = await (select(serialNumbers)
          ..where((s) => s.id.equals(serialNumberId)))
        .getSingleOrNull();

    if (serial == null) return null;

    final product = await (select(products)
          ..where((p) => p.id.equals(serial.productId)))
        .getSingleOrNull();

    if (product == null) return null;

    final isUnderWarranty = serial.warrantyEndDate != null &&
        serial.warrantyEndDate!.isAfter(DateTime.now());

    return WarrantyInfo(
      serialNumber: serial.serialNumber,
      productName: product.name,
      soldDate: serial.warrantyStartDate,
      warrantyExpiry: serial.warrantyEndDate,
      warrantyMonths: product.warrantyMonths,
      isUnderWarranty: isUnderWarranty,
    );
  }

  // ==================== Summary ====================

  Future<RepairSummary> getRepairSummary() async {
    final allJobs = await getAllRepairJobs();

    int activeJobs = 0;
    int pendingJobs = 0;
    int completedToday = 0;
    double revenue = 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    for (final jobWithCustomer in allJobs) {
      final job = jobWithCustomer.repairJob;
      final status = RepairStatusExtension.fromString(job.status);

      if (status != RepairStatus.delivered && status != RepairStatus.cancelled) {
        activeJobs++;
      }

      if (status == RepairStatus.received || status == RepairStatus.diagnosing) {
        pendingJobs++;
      }

      if (job.completedDate != null &&
          job.completedDate!.isAfter(startOfDay)) {
        completedToday++;
      }

      if (status == RepairStatus.delivered) {
        revenue += job.totalCost;
      }
    }

    return RepairSummary(
      activeJobs: activeJobs,
      pendingJobs: pendingJobs,
      completedToday: completedToday,
      totalRevenue: revenue,
    );
  }

  // ==================== Service Invoice Generation ====================

  /// Generate a service invoice for a completed repair job
  /// Supports partial payments - remaining balance goes to customer credit
  /// Returns existing invoice if already generated (prevents duplicates)
  Future<ServiceInvoiceResult> generateServiceInvoice({
    required String repairJobId,
    bool isCredit = false,
    double discountAmount = 0,
    double? partialPayment, // Optional partial payment amount
    String? notes,
    String? createdBy,
  }) async {
    // Get repair job details first (outside transaction to check for existing invoice)
    final job = await getRepairJobById(repairJobId);
    if (job == null) {
      throw Exception('Repair job not found');
    }

    // Check if invoice already exists for this repair job
    if (job.invoiceId != null && job.invoiceId!.isNotEmpty) {
      // Return existing invoice instead of creating duplicate
      final existingSale = await (select(sales)..where((s) => s.id.equals(job.invoiceId!))).getSingleOrNull();
      if (existingSale != null) {
        return ServiceInvoiceResult(
          sale: existingSale,
          invoiceNumber: existingSale.invoiceNumber,
          repairJobNumber: job.jobNumber,
          wasExisting: true,
        );
      }
    }

    return transaction(() async {
      final status = RepairStatusExtension.fromString(job.status);
      if (status != RepairStatus.completed &&
          status != RepairStatus.readyForPickup &&
          status != RepairStatus.delivered) {
        throw Exception('Repair job must be completed before generating invoice');
      }

      // Credit repairs require a customer
      if (isCredit && (job.customerId == null || job.customerId!.isEmpty)) {
        throw Exception('Credit repairs require a registered customer');
      }

      // Get repair parts
      final parts = await getRepairParts(repairJobId);

      // Generate invoice number
      final invoiceNumber = await attachedDatabase.getNextSequenceNumber('INVOICE');
      final saleId = _uuid.v4();
      final now = DateTime.now();

      // Calculate totals
      // Labor is the service charge, parts are the products used
      double partsCost = 0;
      double partsPrice = 0;
      for (final p in parts) {
        partsCost += p.part.unitCost * p.part.quantity;
        partsPrice += p.part.unitPrice * p.part.quantity;
      }

      // Subtotal = labor + parts price
      final subtotal = job.laborCost + partsPrice;
      final totalAmount = subtotal - discountAmount;

      // Total cost = parts cost (labor has no cost, it's pure profit)
      final totalCost = partsCost;
      final grossProfit = subtotal - totalCost - discountAmount;

      // Determine paid amount
      // If partial payment is provided, use it; otherwise full payment or 0 for credit
      double paidAmount;
      if (partialPayment != null) {
        paidAmount = partialPayment.clamp(0, totalAmount);
        // If there's remaining balance, treat as credit
        if (paidAmount < totalAmount) {
          isCredit = true;
        }
      } else {
        paidAmount = isCredit ? 0 : totalAmount;
      }

      // Create sale record
      await into(sales).insert(SalesCompanion.insert(
        id: saleId,
        invoiceNumber: invoiceNumber,
        saleDate: now,
        customerId: Value(job.customerId),
        subtotal: Value(subtotal),
        discountAmount: Value(discountAmount),
        taxAmount: const Value(0),
        totalAmount: Value(totalAmount),
        paidAmount: Value(paidAmount),
        totalCost: Value(totalCost),
        grossProfit: Value(grossProfit),
        isCredit: Value(isCredit),
        status: const Value('COMPLETED'),
        notes: Value('Service Invoice for Repair Job: ${job.jobNumber}${notes != null ? '\n$notes' : ''}'),
        createdBy: Value(createdBy),
      ));

      // Create sale item for labor (as a service item)
      if (job.laborCost > 0) {
        final laborTotalPrice = job.laborCost;
        final laborTotalCost = 0.0;
        final laborProfit = laborTotalPrice - laborTotalCost;
        await into(saleItems).insert(SaleItemsCompanion.insert(
          id: _uuid.v4(),
          saleId: saleId,
          productId: 'SERVICE_LABOR', // Special ID for labor
          quantity: 1,
          unitPrice: job.laborCost,
          unitCost: 0, // No cost for labor
          totalPrice: laborTotalPrice,
          totalCost: laborTotalCost,
          profit: laborProfit,
        ));
      }

      // Create sale items for parts
      for (final part in parts) {
        final partTotalPrice = part.part.unitPrice * part.part.quantity;
        final partTotalCost = part.part.unitCost * part.part.quantity;
        final partProfit = partTotalPrice - partTotalCost;
        await into(saleItems).insert(SaleItemsCompanion.insert(
          id: _uuid.v4(),
          saleId: saleId,
          productId: part.part.productId,
          quantity: part.part.quantity,
          unitPrice: part.part.unitPrice,
          unitCost: part.part.unitCost,
          totalPrice: partTotalPrice,
          totalCost: partTotalCost,
          profit: partProfit,
        ));
      }

      // If credit sale (partial or full credit), create credit transaction
      if (isCredit && job.customerId != null && job.customerId!.isNotEmpty) {
        // Calculate credit amount (total - paid)
        final creditAmount = totalAmount - paidAmount;

        if (creditAmount > 0) {
          // Get current balance to calculate new balance
          final customer = await (select(customers)
                ..where((c) => c.id.equals(job.customerId!)))
              .getSingle();
          final newBalance = customer.creditBalance + creditAmount;

          final paymentNote = paidAmount > 0
              ? 'Service Invoice: $invoiceNumber (Partial payment: ${paidAmount.toStringAsFixed(2)})'
              : 'Service Invoice: $invoiceNumber';

          await into(creditTransactions).insert(CreditTransactionsCompanion.insert(
            id: _uuid.v4(),
            customerId: job.customerId!,
            transactionType: 'SALE',
            amount: creditAmount, // Only record the unpaid amount as credit
            balanceAfter: newBalance,
            transactionDate: now,
            referenceId: Value(saleId),
            notes: Value(paymentNote),
            createdBy: Value(createdBy),
          ));

          // Update customer credit balance
          await (update(customers)..where((c) => c.id.equals(job.customerId!))).write(
            CustomersCompanion(
              creditBalance: Value(newBalance),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // Update repair job with invoiceId to prevent duplicates
      await (update(repairJobs)..where((j) => j.id.equals(repairJobId))).write(
        RepairJobsCompanion(
          invoiceId: Value(saleId),
          notes: Value('${job.notes ?? ''}${job.notes != null ? '\n' : ''}Invoice Generated: $invoiceNumber'),
          updatedAt: Value(now),
        ),
      );

      // Get created sale
      final sale = await (select(sales)..where((s) => s.id.equals(saleId))).getSingle();

      return ServiceInvoiceResult(
        sale: sale,
        invoiceNumber: invoiceNumber,
        repairJobNumber: job.jobNumber,
        wasExisting: false,
      );
    });
  }
}

// ==================== Helper Classes ====================

class RepairJobWithCustomer {
  final RepairJob repairJob;
  final Customer? customer;

  RepairJobWithCustomer({
    required this.repairJob,
    this.customer,
  });

  String get jobNumber => repairJob.jobNumber;
  String get deviceType => repairJob.deviceType;
  String get status => repairJob.status;
  RepairStatus get statusEnum => RepairStatusExtension.fromString(status);
  // Returns customer name from database or manual customer name
  String? get customerName => customer?.name ?? repairJob.manualCustomerName;
  String? get customerPhone => customer?.phone ?? repairJob.manualCustomerPhone;
  bool get isManualCustomer => repairJob.customerId == null && repairJob.manualCustomerName != null;
  DateTime get receivedDate => repairJob.receivedDate;
  double get totalCost => repairJob.totalCost;
}

class RepairJobDetail {
  final RepairJob repairJob;
  final Customer? customer;
  final List<RepairPartWithProduct> parts;
  final List<RepairStatusHistoryData> statusHistory;
  final WarrantyInfo? warrantyInfo;

  RepairJobDetail({
    required this.repairJob,
    this.customer,
    required this.parts,
    required this.statusHistory,
    this.warrantyInfo,
  });

  String get jobNumber => repairJob.jobNumber;
  double get totalCost => repairJob.totalCost;
  double get laborCost => repairJob.laborCost;
  double get partsCost => repairJob.partsCost;
  bool get isUnderWarranty => repairJob.isUnderWarranty;
}

class RepairPartWithProduct {
  final RepairPart part;
  final Product? product;

  RepairPartWithProduct({
    required this.part,
    this.product,
  });

  String get productName => product?.name ?? 'Unknown Product';
  String get productCode => product?.code ?? '';
}

class WarrantyInfo {
  final String serialNumber;
  final String productName;
  final DateTime? soldDate;
  final DateTime? warrantyExpiry;
  final int warrantyMonths;
  final bool isUnderWarranty;

  WarrantyInfo({
    required this.serialNumber,
    required this.productName,
    this.soldDate,
    this.warrantyExpiry,
    required this.warrantyMonths,
    required this.isUnderWarranty,
  });

  int get daysRemaining {
    if (warrantyExpiry == null) return 0;
    return warrantyExpiry!.difference(DateTime.now()).inDays;
  }
}

class RepairSummary {
  final int activeJobs;
  final int pendingJobs;
  final int completedToday;
  final double totalRevenue;

  RepairSummary({
    required this.activeJobs,
    required this.pendingJobs,
    required this.completedToday,
    required this.totalRevenue,
  });
}

class ServiceInvoiceResult {
  final Sale sale;
  final String invoiceNumber;
  final String repairJobNumber;
  final bool wasExisting; // True if invoice already existed (not newly created)

  ServiceInvoiceResult({
    required this.sale,
    required this.invoiceNumber,
    required this.repairJobNumber,
    this.wasExisting = false,
  });
}
