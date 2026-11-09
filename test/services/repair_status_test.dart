import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/data/local/daos/repair_dao.dart';
import 'package:cp_pos/data/local/database/app_database.dart';

void main() {
  test('jobs can jump to any status and be marked shipped', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.repairJobs).insert(RepairJobsCompanion.insert(
        id: 'j1', jobNumber: 'RJ-1', deviceType: 'LAPTOP',
        problemDescription: 'No power', receivedDate: DateTime.now()));

    // Diagnosing -> Ready for Pickup directly (used to be blocked)
    expect(await db.repairDao.updateStatus(jobId: 'j1', newStatus: RepairStatus.diagnosing), true);
    expect(await db.repairDao.updateStatus(jobId: 'j1', newStatus: RepairStatus.readyForPickup), true);
    expect((await db.repairDao.getActiveRepairJobs()).length, 1);

    // Online delivery
    expect(await db.repairDao.updateStatus(jobId: 'j1', newStatus: RepairStatus.shipped), true);
    final job = (await db.repairDao.getRepairJobById('j1'))!;
    expect(job.status, 'SHIPPED');
    expect(job.deliveredDate, isNotNull);
    expect((await db.repairDao.getActiveRepairJobs()).length, 0);

    // Closed jobs are locked
    expect(await db.repairDao.updateStatus(jobId: 'j1', newStatus: RepairStatus.inProgress), false);
    await db.close();
  });
}
