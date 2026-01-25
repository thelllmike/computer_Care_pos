import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/repair_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// Provider for repair summary
final repairSummaryProvider = FutureProvider<RepairSummary>((ref) {
  final db = ref.watch(databaseProvider);
  return db.repairDao.getRepairSummary();
});

// Provider for all repair jobs
final repairJobsProvider = FutureProvider<List<RepairJobWithCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.repairDao.getAllRepairJobs();
});

// Provider for active repair jobs
final activeRepairJobsProvider = FutureProvider<List<RepairJobWithCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.repairDao.getActiveRepairJobs();
});

// Provider for repair jobs by status
final repairJobsByStatusProvider = FutureProvider.family<List<RepairJobWithCustomer>, RepairStatus?>((ref, status) {
  final db = ref.watch(databaseProvider);
  if (status == null) {
    return db.repairDao.getAllRepairJobs();
  }
  return db.repairDao.getRepairJobsByStatus(status);
});

// Provider for repair job detail
final repairJobDetailProvider = FutureProvider.family<RepairJobDetail?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.repairDao.getRepairJobDetail(id);
});

// Provider for warranty check
final warrantyCheckProvider = FutureProvider.family<WarrantyInfo?, String>((ref, serialNumberId) {
  final db = ref.watch(databaseProvider);
  return db.repairDao.checkWarranty(serialNumberId);
});

// ==================== Repair Form State Management ====================

class RepairFormState {
  final String? repairJobId;
  final String? customerId;
  final String? customerName;
  final String? manualCustomerName; // For walk-in customers
  final String? manualCustomerPhone;
  final bool useManualCustomer;
  final String deviceType;
  final String? deviceBrand;
  final String? deviceModel;
  final String? deviceSerial;
  final String? serialNumberId;
  final String problemDescription;
  final String? diagnosis;
  final double estimatedCost;
  final double laborCost;
  final DateTime? promisedDate;
  final String? assignedTo;
  final String? notes;
  final WarrantyInfo? warrantyInfo;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  RepairFormState({
    this.repairJobId,
    this.customerId,
    this.customerName,
    this.manualCustomerName,
    this.manualCustomerPhone,
    this.useManualCustomer = false,
    this.deviceType = 'LAPTOP',
    this.deviceBrand,
    this.deviceModel,
    this.deviceSerial,
    this.serialNumberId,
    this.problemDescription = '',
    this.diagnosis,
    this.estimatedCost = 0,
    this.laborCost = 0,
    this.promisedDate,
    this.assignedTo,
    this.notes,
    this.warrantyInfo,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  bool get isEditing => repairJobId != null;
  bool get isOurDevice => serialNumberId != null;
  bool get isUnderWarranty => warrantyInfo?.isUnderWarranty ?? false;

  RepairFormState copyWith({
    String? repairJobId,
    String? customerId,
    String? customerName,
    String? manualCustomerName,
    String? manualCustomerPhone,
    bool? useManualCustomer,
    String? deviceType,
    String? deviceBrand,
    String? deviceModel,
    String? deviceSerial,
    String? serialNumberId,
    String? problemDescription,
    String? diagnosis,
    double? estimatedCost,
    double? laborCost,
    DateTime? promisedDate,
    String? assignedTo,
    String? notes,
    WarrantyInfo? warrantyInfo,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearCustomer = false,
    bool clearSerial = false,
    bool clearManualCustomer = false,
  }) {
    return RepairFormState(
      repairJobId: repairJobId ?? this.repairJobId,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      manualCustomerName: clearManualCustomer ? null : (manualCustomerName ?? this.manualCustomerName),
      manualCustomerPhone: clearManualCustomer ? null : (manualCustomerPhone ?? this.manualCustomerPhone),
      useManualCustomer: useManualCustomer ?? this.useManualCustomer,
      deviceType: deviceType ?? this.deviceType,
      deviceBrand: deviceBrand ?? this.deviceBrand,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceSerial: clearSerial ? null : (deviceSerial ?? this.deviceSerial),
      serialNumberId: clearSerial ? null : (serialNumberId ?? this.serialNumberId),
      problemDescription: problemDescription ?? this.problemDescription,
      diagnosis: diagnosis ?? this.diagnosis,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      laborCost: laborCost ?? this.laborCost,
      promisedDate: promisedDate ?? this.promisedDate,
      assignedTo: assignedTo ?? this.assignedTo,
      notes: notes ?? this.notes,
      warrantyInfo: clearSerial ? null : (warrantyInfo ?? this.warrantyInfo),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }

  // Get display customer name
  String? get displayCustomerName => useManualCustomer ? manualCustomerName : customerName;
  bool get hasCustomer => useManualCustomer ? (manualCustomerName?.isNotEmpty ?? false) : (customerId != null);
}

class RepairFormNotifier extends StateNotifier<RepairFormState> {
  final AppDatabase _db;
  final Ref _ref;

  RepairFormNotifier(this._db, this._ref) : super(RepairFormState(
    promisedDate: DateTime.now().add(const Duration(days: 3)),
  ));

  // Set customer
  void setCustomer(String? customerId, String? customerName) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
      useManualCustomer: false,
      clearCustomer: customerId == null,
      clearManualCustomer: true,
    );
  }

  // Set manual customer (walk-in)
  void setManualCustomer(String? name, String? phone) {
    state = state.copyWith(
      manualCustomerName: name,
      manualCustomerPhone: phone,
      useManualCustomer: true,
      clearCustomer: true,
    );
  }

  // Toggle between database customer and manual customer
  void setUseManualCustomer(bool useManual) {
    state = state.copyWith(
      useManualCustomer: useManual,
      clearCustomer: useManual,
      clearManualCustomer: !useManual,
    );
  }

  // Set device type
  void setDeviceType(String deviceType) {
    state = state.copyWith(deviceType: deviceType);
  }

  // Set device info
  void setDeviceInfo({
    String? brand,
    String? model,
    String? serial,
  }) {
    state = state.copyWith(
      deviceBrand: brand,
      deviceModel: model,
      deviceSerial: serial,
    );
  }

  // Set serial (our device)
  Future<void> setSerialNumber(String? serialNumberId, String? serialNumber) async {
    if (serialNumberId == null) {
      state = state.copyWith(clearSerial: true);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final warrantyInfo = await _db.repairDao.checkWarranty(serialNumberId);
      state = state.copyWith(
        serialNumberId: serialNumberId,
        deviceSerial: serialNumber,
        warrantyInfo: warrantyInfo,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Set problem description
  void setProblemDescription(String description) {
    state = state.copyWith(problemDescription: description);
  }

  // Set diagnosis
  void setDiagnosis(String? diagnosis) {
    state = state.copyWith(diagnosis: diagnosis);
  }

  // Set estimated cost
  void setEstimatedCost(double cost) {
    state = state.copyWith(estimatedCost: cost);
  }

  // Set labor cost
  void setLaborCost(double cost) {
    state = state.copyWith(laborCost: cost);
  }

  // Set promised date
  void setPromisedDate(DateTime? date) {
    state = state.copyWith(promisedDate: date);
  }

  // Set assigned to
  void setAssignedTo(String? assignedTo) {
    state = state.copyWith(assignedTo: assignedTo);
  }

  // Set notes
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  // Save repair job
  Future<RepairJob?> saveRepairJob({String? createdBy}) async {
    if (!state.hasCustomer) {
      state = state.copyWith(error: 'Please select or enter a customer');
      return null;
    }

    if (state.problemDescription.isEmpty) {
      state = state.copyWith(error: 'Please enter problem description');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      RepairJob job;

      if (state.isEditing) {
        await _db.repairDao.updateRepairJob(
          id: state.repairJobId!,
          diagnosis: state.diagnosis,
          estimatedCost: state.estimatedCost,
          laborCost: state.laborCost,
          promisedDate: state.promisedDate,
          assignedTo: state.assignedTo,
          notes: state.notes,
        );
        job = (await _db.repairDao.getRepairJobById(state.repairJobId!))!;
      } else {
        job = await _db.repairDao.createRepairJob(
          customerId: state.useManualCustomer ? null : state.customerId,
          manualCustomerName: state.useManualCustomer ? state.manualCustomerName : null,
          manualCustomerPhone: state.useManualCustomer ? state.manualCustomerPhone : null,
          deviceType: state.deviceType,
          problemDescription: state.problemDescription,
          serialNumberId: state.serialNumberId,
          deviceBrand: state.deviceBrand,
          deviceModel: state.deviceModel,
          deviceSerial: state.deviceSerial,
          estimatedCost: state.estimatedCost,
          promisedDate: state.promisedDate,
          receivedBy: createdBy,
          notes: state.notes,
        );
      }

      // Invalidate providers
      _ref.invalidate(repairJobsProvider);
      _ref.invalidate(activeRepairJobsProvider);
      _ref.invalidate(repairSummaryProvider);

      state = state.copyWith(isSaving: false);
      return job;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  // Load existing repair job for editing
  Future<void> loadRepairJob(String repairJobId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final detail = await _db.repairDao.getRepairJobDetail(repairJobId);
      if (detail == null) {
        state = state.copyWith(isLoading: false, error: 'Repair job not found');
        return;
      }

      state = RepairFormState(
        repairJobId: detail.repairJob.id,
        customerId: detail.repairJob.customerId,
        customerName: detail.customer?.name,
        deviceType: detail.repairJob.deviceType,
        deviceBrand: detail.repairJob.deviceBrand,
        deviceModel: detail.repairJob.deviceModel,
        deviceSerial: detail.repairJob.deviceSerial,
        serialNumberId: detail.repairJob.serialNumberId,
        problemDescription: detail.repairJob.problemDescription,
        diagnosis: detail.repairJob.diagnosis,
        estimatedCost: detail.repairJob.estimatedCost,
        laborCost: detail.repairJob.laborCost,
        promisedDate: detail.repairJob.promisedDate,
        assignedTo: detail.repairJob.assignedTo,
        notes: detail.repairJob.notes,
        warrantyInfo: detail.warrantyInfo,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Clear form
  void clear() {
    state = RepairFormState(
      promisedDate: DateTime.now().add(const Duration(days: 3)),
    );
  }
}

final repairFormProvider = StateNotifierProvider<RepairFormNotifier, RepairFormState>((ref) {
  final db = ref.watch(databaseProvider);
  return RepairFormNotifier(db, ref);
});

// ==================== Status Update State ====================

class StatusUpdateState {
  final bool isProcessing;
  final bool isSuccess;
  final String? error;

  StatusUpdateState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.error,
  });

  StatusUpdateState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? error,
  }) {
    return StatusUpdateState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

class StatusUpdateNotifier extends StateNotifier<StatusUpdateState> {
  final AppDatabase _db;
  final Ref _ref;

  StatusUpdateNotifier(this._db, this._ref) : super(StatusUpdateState());

  Future<void> updateStatus({
    required String jobId,
    required RepairStatus newStatus,
    String? changedBy,
    String? notes,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final success = await _db.repairDao.updateStatus(
        jobId: jobId,
        newStatus: newStatus,
        changedBy: changedBy,
        notes: notes,
      );

      if (!success) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Invalid status transition',
        );
        return;
      }

      // Invalidate providers
      _ref.invalidate(repairJobsProvider);
      _ref.invalidate(activeRepairJobsProvider);
      _ref.invalidate(repairSummaryProvider);
      _ref.invalidate(repairJobDetailProvider(jobId));

      state = state.copyWith(isProcessing: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }

  void reset() {
    state = StatusUpdateState();
  }
}

final statusUpdateProvider = StateNotifierProvider<StatusUpdateNotifier, StatusUpdateState>((ref) {
  final db = ref.watch(databaseProvider);
  return StatusUpdateNotifier(db, ref);
});

// ==================== Parts Management State ====================

class PartsManagementState {
  final bool isProcessing;
  final String? error;

  PartsManagementState({
    this.isProcessing = false,
    this.error,
  });
}

class PartsManagementNotifier extends StateNotifier<PartsManagementState> {
  final AppDatabase _db;
  final Ref _ref;

  PartsManagementNotifier(this._db, this._ref) : super(PartsManagementState());

  Future<bool> addPart({
    required String repairJobId,
    required String productId,
    required int quantity,
    required double unitCost,
    required double unitPrice,
    String? serialNumberId,
  }) async {
    state = PartsManagementState(isProcessing: true);

    try {
      await _db.repairDao.addRepairPart(
        repairJobId: repairJobId,
        productId: productId,
        quantity: quantity,
        unitCost: unitCost,
        unitPrice: unitPrice,
        serialNumberId: serialNumberId,
      );

      _ref.invalidate(repairJobDetailProvider(repairJobId));

      state = PartsManagementState();
      return true;
    } catch (e) {
      state = PartsManagementState(error: e.toString());
      return false;
    }
  }

  Future<bool> removePart(String partId, String repairJobId) async {
    state = PartsManagementState(isProcessing: true);

    try {
      await _db.repairDao.removeRepairPart(partId);
      _ref.invalidate(repairJobDetailProvider(repairJobId));

      state = PartsManagementState();
      return true;
    } catch (e) {
      state = PartsManagementState(error: e.toString());
      return false;
    }
  }
}

final partsManagementProvider = StateNotifierProvider<PartsManagementNotifier, PartsManagementState>((ref) {
  final db = ref.watch(databaseProvider);
  return PartsManagementNotifier(db, ref);
});

// ==================== Service Invoice Generation ====================

class ServiceInvoiceState {
  final bool isProcessing;
  final bool isSuccess;
  final String? invoiceNumber;
  final String? error;

  ServiceInvoiceState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.invoiceNumber,
    this.error,
  });

  ServiceInvoiceState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? invoiceNumber,
    String? error,
  }) {
    return ServiceInvoiceState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      error: error,
    );
  }
}

class ServiceInvoiceNotifier extends StateNotifier<ServiceInvoiceState> {
  final AppDatabase _db;
  final Ref _ref;

  ServiceInvoiceNotifier(this._db, this._ref) : super(ServiceInvoiceState());

  Future<ServiceInvoiceResult?> generateInvoice({
    required String repairJobId,
    bool isCredit = false,
    double discountAmount = 0,
    double? partialPayment, // Optional partial payment for credit repairs
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final result = await _db.repairDao.generateServiceInvoice(
        repairJobId: repairJobId,
        isCredit: isCredit,
        discountAmount: discountAmount,
        partialPayment: partialPayment,
        notes: notes,
        createdBy: createdBy,
      );

      // Invalidate providers
      _ref.invalidate(repairJobDetailProvider(repairJobId));
      _ref.invalidate(repairSummaryProvider);

      state = state.copyWith(
        isProcessing: false,
        isSuccess: true,
        invoiceNumber: result.invoiceNumber,
      );

      return result;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      return null;
    }
  }

  void reset() {
    state = ServiceInvoiceState();
  }
}

final serviceInvoiceProvider = StateNotifierProvider<ServiceInvoiceNotifier, ServiceInvoiceState>((ref) {
  final db = ref.watch(databaseProvider);
  return ServiceInvoiceNotifier(db, ref);
});

// ==================== Search and Filter State ====================

final repairSearchQueryProvider = StateProvider<String>((ref) => '');
final repairStatusFilterProvider = StateProvider<RepairStatus?>((ref) => null);
