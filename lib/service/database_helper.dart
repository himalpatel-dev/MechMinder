import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "VehicleManager.db";
  // --- We are keeping this at Version 1 ---
  static const _databaseVersion = 1;

  // --- Table Names (unchanged) ---
  static const tableVehicles = 'vehicles';
  static const tableServices = 'services';
  static const tableServiceItems = 'service_items';
  static const tableServiceTemplates = 'service_templates';
  static const tableReminders = 'reminders';
  static const tableVendors = 'vendors';
  static const tableExpenses = 'expenses';
  static const tablePhotos = 'photos';

  // --- Common Column Names (unchanged) ---
  static const columnId = '_id';
  static const columnCreatedAt = 'created_at';

  // --- vehicles Table Columns (unchanged) ---
  static const columnUserId = 'user_id';
  static const columnMake = 'make';
  static const columnModel = 'model';
  static const columnRegNo = 'reg_no';
  static const columnInitialOdometer = 'initial_odometer';
  static const columnCurrentOdometer = 'current_odometer';
  static const columnVariant = 'variant'; // <-- NEW
  static const columnPurchaseDate = 'purchase_date'; // <-- RENAMED
  static const columnFuelType = 'fuel_type'; // <-- NEW
  static const columnVehicleColor = 'vehicle_color'; // <-- NEW
  static const columnOwnerName = 'owner_name'; // <-- NEW
  static const columnOdometerUpdatedAt =
      'odometer_updated_at'; // <-- NEW COLUMN

  // --- services Table Columns (NEW COLUMN ADDED) ---
  static const columnVehicleId = 'vehicle_id';
  static const columnServiceName = 'service_name';
  static const columnServiceDate = 'service_date';
  static const columnOdometer = 'odometer';
  static const columnTotalCost = 'total_cost';
  static const columnVendorId = 'vendor_id';
  static const columnTemplateId = 'template_id';
  static const columnNotes = 'notes';

  // --- VehiclePapers Table Columns ---
  static const tableVehiclePapers = 'vehicle_papers';
  static const columnPaperType = 'type'; // e.g., 'Insurance', 'PUC'
  static const columnReferenceNo = 'reference_no'; // <-- RENAMED
  static const columnDescription = 'description'; // <-- NEW
  static const columnCost = 'cost'; // <-- NEW
  static const columnProviderName = 'provider_name'; // <-- ADD THIS
  static const columnPaperExpiryDate = 'expiry_date';
  static const columnFilePath = 'file_path';

  // --- Documents (General) Table Columns ---
  static const tableDocuments = 'documents';
  static const columnDocType = 'doc_type';

  // --- (All other column names are unchanged) ---
  static const columnServiceId = 'service_id';
  static const columnName = 'name';
  static const columnQty = 'qty';
  static const columnUnitCost = 'unit_cost';
  static const columnIntervalDays = 'interval_days';
  static const columnIntervalKm = 'interval_km';
  static const columnVehicleType = 'vehicle_type';
  static const columnDueDate = 'due_date';
  static const columnDueOdometer = 'due_odometer';
  static const columnRecurrenceRule = 'recurrence_rule';
  static const columnLeadTimeDays = 'lead_time_days';
  static const columnLeadTimeKm = 'lead_time_km';
  static const columnLastNotifiedAt = 'last_notified_at';
  static const columnPhone = 'phone';
  static const columnAddress = 'address';
  static const columnCategory = 'category';
  static const columnParentType = 'parent_type';
  static const columnParentId = 'parent_id';
  static const columnUri = 'uri';
  static const columnStatus = 'status'; // Will be 'pending' or 'completed'
  static const columnCompletedByServiceId =
      'completed_by_service_id'; // Links to the service that completed it

  // --- Singleton Class Setup (unchanged) ---
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // --- _initDatabase (NO onUpgrade) ---
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      // No onUpgrade needed!
    );
  }

  // (onConfigure is unchanged)
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // --- _onCreate (UPDATED) ---
  Future _onCreate(Database db, int version) async {
    // vehicles table is unchanged (already has current_odometer)
    await db.execute('''
        CREATE TABLE $tableVehicles (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnMake TEXT NOT NULL,
          $columnModel TEXT NOT NULL,
          $columnVariant TEXT,               
          $columnPurchaseDate TEXT,       
          $columnFuelType TEXT NOT NULL,   
          $columnVehicleColor TEXT,        
          $columnRegNo TEXT,
          $columnOwnerName TEXT NOT NULL,  
          $columnInitialOdometer INTEGER,
          $columnCurrentOdometer INTEGER,
          $columnOdometerUpdatedAt TEXT
        )
      ''');

    // vendors table is unchanged
    await db.execute('''
      CREATE TABLE $tableVendors (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL,
        $columnPhone TEXT,
        $columnAddress TEXT
      )
    ''');

    // --- services Table IS UPDATED ---
    await db.execute('''
      CREATE TABLE $tableServices (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnVehicleId INTEGER NOT NULL,
        $columnServiceName TEXT,
        $columnServiceDate TEXT NOT NULL,
        $columnOdometer INTEGER,
        $columnTotalCost REAL,
        $columnVendorId INTEGER,
        $columnTemplateId INTEGER,
        $columnNotes TEXT,
        $columnCreatedAt TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY ($columnVehicleId) REFERENCES $tableVehicles ($columnId) ON DELETE CASCADE,
        FOREIGN KEY ($columnVendorId) REFERENCES $tableVendors ($columnId) ON DELETE SET NULL
      )
    ''');

    // (All other tables are unchanged)
    await db.execute('''
      CREATE TABLE $tableServiceItems (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnServiceId INTEGER NOT NULL,
        $columnName TEXT NOT NULL,
        $columnQty REAL,
        $columnUnitCost REAL,
        $columnTotalCost REAL,
        $columnTemplateId INTEGER,
        FOREIGN KEY ($columnServiceId) REFERENCES $tableServices ($columnId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableServiceTemplates (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL UNIQUE,
        $columnIntervalDays INTEGER,
        $columnIntervalKm INTEGER,
        $columnVehicleType TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableReminders (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnVehicleId INTEGER NOT NULL,
        $columnTemplateId INTEGER,
        $columnServiceId INTEGER,
        $columnDueDate TEXT,
        $columnDueOdometer INTEGER,
        $columnNotes TEXT,
        $columnRecurrenceRule TEXT,
        $columnLeadTimeDays INTEGER,
        $columnLeadTimeKm INTEGER,
        $columnLastNotifiedAt TEXT,
        $columnStatus TEXT NOT NULL DEFAULT 'pending', 
        $columnCompletedByServiceId INTEGER,
        FOREIGN KEY ($columnVehicleId) REFERENCES $tableVehicles ($columnId) ON DELETE CASCADE,
        FOREIGN KEY ($columnTemplateId) REFERENCES $tableServiceTemplates ($columnId) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableExpenses (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnVehicleId INTEGER NOT NULL,
        $columnServiceDate TEXT NOT NULL,
        $columnCategory TEXT NOT NULL,
        $columnTotalCost REAL,
        $columnNotes TEXT,
        FOREIGN KEY ($columnVehicleId) REFERENCES $tableVehicles ($columnId) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE $tablePhotos (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnParentType TEXT NOT NULL,
        $columnParentId INTEGER NOT NULL,
        $columnUri TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableVehiclePapers (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnVehicleId INTEGER NOT NULL,
        $columnPaperType TEXT NOT NULL,
        $columnReferenceNo TEXT, 
        $columnProviderName TEXT, 
        $columnDescription TEXT,
        $columnCost REAL,
        $columnPaperExpiryDate TEXT,
        $columnFilePath TEXT, 
        FOREIGN KEY ($columnVehicleId) REFERENCES $tableVehicles ($columnId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
          CREATE TABLE $tableDocuments (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnVehicleId INTEGER, 
            $columnDocType TEXT,
            $columnDescription TEXT,
            $columnFilePath TEXT NOT NULL, 
            FOREIGN KEY ($columnVehicleId) REFERENCES $tableVehicles ($columnId) ON DELETE CASCADE
          )
        ''');

    // --- OPTIMIZATION: Indexes ---
    // Adding indexes speed up specific queries significantly.

    // 1. Vehicles
    // (Id is already indexed by PK)

    // 2. Services
    await db.execute(
      'CREATE INDEX idx_services_vehicle_id ON $tableServices ($columnVehicleId)',
    );
    await db.execute(
      'CREATE INDEX idx_services_date ON $tableServices ($columnServiceDate)',
    );

    // 3. Service Items
    await db.execute(
      'CREATE INDEX idx_service_items_service_id ON $tableServiceItems ($columnServiceId)',
    );

    // 4. Reminders
    await db.execute(
      'CREATE INDEX idx_reminders_vehicle_id ON $tableReminders ($columnVehicleId)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_status ON $tableReminders ($columnStatus)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_due_date ON $tableReminders ($columnDueDate)',
    );

    // 5. Expenses
    await db.execute(
      'CREATE INDEX idx_expenses_vehicle_id ON $tableExpenses ($columnVehicleId)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_category ON $tableExpenses ($columnCategory)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_date ON $tableExpenses ($columnServiceDate)',
    );

    // 6. Papers
    await db.execute(
      'CREATE INDEX idx_papers_vehicle_id ON $tableVehiclePapers ($columnVehicleId)',
    );
    await db.execute(
      'CREATE INDEX idx_papers_expiry ON $tableVehiclePapers ($columnPaperExpiryDate)',
    );

    // 7. Photos
    await db.execute(
      'CREATE INDEX idx_photos_parent ON $tablePhotos ($columnParentId, $columnParentType)',
    );

    // 8. Documents
    await db.execute(
      'CREATE INDEX idx_documents_vehicle_id ON $tableDocuments ($columnVehicleId)',
    );
  }

  // --- FIX 3: REMOVE THE _onUpgrade FUNCTION ENTIRELY ---

  // --- (All other helper functions) ---
  Future<int> insertVehicle(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableVehicles, row);
  }

  Future<List<Map<String, dynamic>>> queryAllVehiclesWithNextReminder() async {
    Database db = await instance.database;
    // We don't strictly filter by date >= today in the query because
    // "Overdue" items (date < today) are actually the 'next' most important thing to show.
    // Sorting by date ASC will put older dates (overdue) first.

    final String sql =
        '''
    SELECT 
      v.*,
      r.$columnDueDate,
      r.$columnDueOdometer,
      t.$columnName AS template_name,
      (
        SELECT p.$columnUri 
        FROM $tablePhotos p 
        WHERE p.$columnParentId = v.$columnId AND p.$columnParentType = 'vehicle'
        LIMIT 1
      ) AS photo_uri
    FROM $tableVehicles v
    LEFT JOIN $tableReminders r ON r.$columnId = (
        SELECT r2.$columnId
        FROM $tableReminders r2
        WHERE r2.$columnVehicleId = v.$columnId 
          AND r2.$columnStatus = 'pending'
        ORDER BY r2.$columnDueDate ASC, r2.$columnDueOdometer ASC
        LIMIT 1
    )
    LEFT JOIN $tableServiceTemplates t ON r.$columnTemplateId = t.$columnId
    ORDER BY v.$columnId DESC
  ''';

    return await db.rawQuery(sql);
  }

  Future<Map<String, dynamic>?> queryVehicleById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      tableVehicles,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<Map<String, Map<String, dynamic>?>> queryNextDueSummary(
    int vehicleId,
  ) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> nextByDate = await db.query(
      tableReminders,
      where:
          '$columnVehicleId = ? AND $columnDueDate IS NOT NULL AND $columnDueDate >= ?',
      whereArgs: [vehicleId, DateTime.now().toIso8601String().split('T')[0]],
      orderBy: '$columnDueDate ASC',
      limit: 1,
    );
    final List<Map<String, dynamic>> nextByOdometer = await db.query(
      tableReminders,
      where: '$columnVehicleId = ? AND $columnDueOdometer IS NOT NULL',
      whereArgs: [vehicleId],
      orderBy: '$columnDueOdometer ASC',
      limit: 1,
    );
    return {
      'nextByDate': nextByDate.isNotEmpty ? nextByDate.first : null,
      'nextByOdometer': nextByOdometer.isNotEmpty ? nextByOdometer.first : null,
    };
  }

  Future<List<Map<String, dynamic>>> queryServicesForVehicle(
    int vehicleId,
  ) async {
    Database db = await instance.database;

    final String sql =
        '''
    SELECT 
      s.*, 
      v.$columnName AS vendor_name,
      (SELECT COUNT(*) FROM $tableServiceItems si WHERE si.$columnServiceId = s.$columnId) AS item_count
    FROM $tableServices s
    LEFT JOIN $tableVendors v ON s.$columnVendorId = v.$columnId
    WHERE s.$columnVehicleId = ?
    ORDER BY s.$columnCreatedAt DESC
  ''';

    return await db.rawQuery(sql, [vehicleId]);
  }

  Future<int> updateVehicleOdometer(int id, int newOdometer) async {
    Database db = await instance.database;
    return await db.update(
      tableVehicles,
      {
        columnCurrentOdometer: newOdometer,
        columnOdometerUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertService(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableServices, row);
  }

  Future<int> insertVendor(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableVendors, row);
  }

  Future<List<Map<String, dynamic>>> queryAllVendors() async {
    Database db = await instance.database;
    return await db.query(tableVendors, orderBy: '$columnName ASC');
  }

  // Inserts a new service template
  Future<int> insertServiceTemplate(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableServiceTemplates, row);
  }

  // Queries all service templates, ordered by name
  Future<List<Map<String, dynamic>>> queryAllServiceTemplates() async {
    Database db = await instance.database;
    return await db.query(tableServiceTemplates, orderBy: '$columnName ASC');
  }

  // Inserts a new service item
  Future<int> insertServiceItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableServiceItems, row);
  }

  // Queries all items for a specific service
  Future<List<Map<String, dynamic>>> queryServiceItems(int serviceId) async {
    Database db = await instance.database;
    return await db.query(
      tableServiceItems,
      where: '$columnServiceId = ?',
      whereArgs: [serviceId],
    );
  }

  // Inserts a new reminder
  Future<int> insertReminder(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableReminders, row);
  }

  // Queries all reminders for a specific vehicle
  Future<List<Map<String, dynamic>>> queryRemindersForVehicle(
    int vehicleId,
  ) async {
    Database db = await instance.database;

    // This query JOINS reminders with templates to get the name
    final String sql =
        '''
      SELECT 
        r.*, 
        t.$columnName AS template_name
      FROM $tableReminders r
      LEFT JOIN $tableServiceTemplates t ON r.$columnTemplateId = t.$columnId
      WHERE r.$columnVehicleId = ? AND r.$columnStatus = 'pending'
      ORDER BY r.$columnDueDate ASC, r.$columnDueOdometer ASC
    ''';

    return await db.rawQuery(sql, [vehicleId]);
  }

  Future<Map<String, dynamic>?> queryTemplateById(int id) async {
    Database db = await instance.database;
    final result = await db.query(
      tableServiceTemplates,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Inserts a new expense
  Future<int> insertExpense(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableExpenses, row);
  }

  // Queries all expenses for a specific vehicle, ordered by date
  Future<List<Map<String, dynamic>>> queryExpensesForVehicle(
    int vehicleId,
  ) async {
    Database db = await instance.database;
    return await db.query(
      tableExpenses,
      where: '$columnVehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: '$columnServiceDate DESC', // Use the date column
    );
  }

  // Calculates the total cost from both services and expenses
  Future<double> queryTotalSpending(
    int vehicleId, {
    String? startDate,
    String? endDate,
  }) async {
    Database db = await instance.database;

    String serviceWhere = '$columnVehicleId = ?';
    String expenseWhere = '$columnVehicleId = ?';
    List<dynamic> serviceArgs = [vehicleId];
    List<dynamic> expenseArgs = [vehicleId];

    if (startDate != null && endDate != null) {
      serviceWhere += ' AND $columnServiceDate BETWEEN ? AND ?';
      expenseWhere += ' AND $columnServiceDate BETWEEN ? AND ?';
      serviceArgs.addAll([startDate, endDate]);
      expenseArgs.addAll([startDate, endDate]);
    }

    // 1. Get total from Services
    final serviceTotalResult = await db.rawQuery(
      'SELECT SUM($columnTotalCost) as total FROM $tableServices WHERE $serviceWhere',
      serviceArgs,
    );
    double serviceTotal =
        serviceTotalResult.isNotEmpty &&
            serviceTotalResult.first['total'] != null
        ? (serviceTotalResult.first['total'] as num).toDouble()
        : 0.0;

    // 2. Get total from Expenses
    final expenseTotalResult = await db.rawQuery(
      'SELECT SUM($columnTotalCost) as total FROM $tableExpenses WHERE $expenseWhere',
      expenseArgs,
    );
    double expenseTotal =
        expenseTotalResult.isNotEmpty &&
            expenseTotalResult.first['total'] != null
        ? (expenseTotalResult.first['total'] as num).toDouble()
        : 0.0;

    // 3. Get total from Papers (Only if NO date filter is applied, as papers don't have a transaction date)
    double paperTotal = 0.0;
    if (startDate == null && endDate == null) {
      final paperTotalResult = await db.rawQuery(
        'SELECT SUM($columnCost) as total FROM $tableVehiclePapers WHERE $columnVehicleId = ?',
        [vehicleId],
      );
      paperTotal =
          paperTotalResult.isNotEmpty && paperTotalResult.first['total'] != null
          ? (paperTotalResult.first['total'] as num).toDouble()
          : 0.0;
    }

    return serviceTotal + expenseTotal + paperTotal;
  }

  // Gets a list of spending grouped by category
  Future<List<Map<String, dynamic>>> querySpendingByCategory(
    int vehicleId, {
    String? startDate,
    String? endDate,
  }) async {
    Database db = await instance.database;

    String serviceWhere = '$columnVehicleId = ?';
    String expenseWhere = '$columnVehicleId = ?';
    List<dynamic> serviceArgs = [vehicleId];
    List<dynamic> expenseArgs = [vehicleId];

    if (startDate != null && endDate != null) {
      serviceWhere += ' AND $columnServiceDate BETWEEN ? AND ?';
      expenseWhere += ' AND $columnServiceDate BETWEEN ? AND ?';
      serviceArgs.addAll([startDate, endDate]);
      expenseArgs.addAll([startDate, endDate]);
    }

    // 1. Get spending from Expenses, grouped by category
    final categoryResult = await db.rawQuery(
      'SELECT $columnCategory, SUM($columnTotalCost) as total FROM $tableExpenses WHERE $expenseWhere GROUP BY $columnCategory',
      expenseArgs,
    );

    // 2. Get total from Services and add it as its own "Service" category
    final serviceTotalResult = await db.rawQuery(
      'SELECT SUM($columnTotalCost) as total FROM $tableServices WHERE $serviceWhere',
      serviceArgs,
    );
    double serviceTotal =
        serviceTotalResult.isNotEmpty &&
            serviceTotalResult.first['total'] != null
        ? (serviceTotalResult.first['total'] as num).toDouble()
        : 0.0;

    List<Map<String, dynamic>> results = List.from(categoryResult);

    // 3. Get total from Papers (Only if NO date filter is applied)
    if (startDate == null && endDate == null) {
      final paperResult = await db.rawQuery(
        'SELECT $columnPaperType, SUM($columnCost) as total FROM $tableVehiclePapers WHERE $columnVehicleId = ? GROUP BY $columnPaperType',
        [vehicleId],
      );
      // Add papers to results, treating paper type as category
      for (var row in paperResult) {
        results.add({
          DatabaseHelper.columnCategory: row[DatabaseHelper.columnPaperType],
          'total': row['total'],
        });
      }
    }

    if (serviceTotal > 0) {
      results.add({
        DatabaseHelper.columnCategory: 'Services', // Add a custom category
        'total': serviceTotal,
      });
    }

    return results;
  }

  // Deletes a reminder by its ID
  Future<int> deleteReminder(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableReminders,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Inserts a new photo
  Future<int> insertPhoto(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tablePhotos, row);
  }

  // Queries all photos for a parent (e.g., a specific vehicle or service)
  Future<List<Map<String, dynamic>>> queryPhotosForParent(
    int parentId,
    String parentType,
  ) async {
    Database db = await instance.database;
    return await db.query(
      tablePhotos,
      where: '$columnParentId = ? AND $columnParentType = ?',
      whereArgs: [parentId, parentType],
    );
  }

  // Deletes a photo by its ID
  Future<int> deletePhoto(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tablePhotos,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Queries a single service by its ID, with vendor name
  Future<Map<String, dynamic>?> queryServiceById(int serviceId) async {
    Database db = await instance.database;

    final String sql =
        '''
      SELECT 
        s.*, 
        v.$columnName AS vendor_name
      FROM $tableServices s
      LEFT JOIN $tableVendors v ON s.$columnVendorId = v.$columnId
      WHERE s.$columnId = ?
    ''';

    final result = await db.rawQuery(sql, [serviceId]);
    return result.isNotEmpty ? result.first : null;
  }

  // Updates an existing vehicle's details
  Future<int> updateVehicle(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableVehicles,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Deletes a vehicle by its ID.
  // Thanks to "ON DELETE CASCADE" in our database, this will
  // ALSO delete all associated services, items, reminders, expenses, and photos.
  Future<int> deleteVehicle(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableVehicles,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> queryAllRows(String tableName) async {
    Database db = await instance.database;
    return await db.query(tableName);
  }

  Future<int> updateService(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableServices,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllServiceItemsForService(int serviceId) async {
    Database db = await instance.database;
    return await db.delete(
      tableServiceItems,
      where: '$columnServiceId = ?',
      whereArgs: [serviceId],
    );
  }

  Future<void> restoreBackup(
    Map<String, dynamic> data, {
    String? fileSourcePath,
  }) async {
    Database db = await instance.database;
    Directory appDocDir =
        await getApplicationDocumentsDirectory(); // For saving files

    // We must use a "transaction" so if *any* part fails,
    // the whole thing is rolled back.
    await db.transaction((txn) async {
      // --- 1. WIPE ALL CURRENT DATA (in correct order) ---
      await txn.delete(tableDocuments); // Wipe last
      await txn.delete(tableVehiclePapers); // Wipe last
      await txn.delete(tablePhotos);
      await txn.delete(tableServiceItems);
      await txn.delete(tableExpenses);
      await txn.delete(tableReminders);
      await txn.delete(tableServices);
      await txn.delete(tableServiceTemplates);
      await txn.delete(tableVendors);
      await txn.delete(tableVehicles);

      // --- 2. CREATE ID MAPPING TABLES ---
      // We need to map old IDs to the new auto-incremented IDs
      Map<int, int> vehicleIdMap = {}; // { oldId: newId }
      Map<int, int> serviceIdMap = {};
      Map<int, int> vendorIdMap = {};
      Map<int, int> templateIdMap = {};

      // --- 3. RESTORE DATA (in correct order) ---

      // Vendors
      for (var row in (data['vendors'] as List)) {
        int oldId = row[columnId];
        row.remove(columnId); // Remove old ID
        int newId = await txn.insert(tableVendors, row as Map<String, dynamic>);
        vendorIdMap[oldId] = newId;
      }

      // Templates
      for (var row in (data['service_templates'] as List)) {
        int oldId = row[columnId];
        row.remove(columnId);
        int newId = await txn.insert(
          tableServiceTemplates,
          row as Map<String, dynamic>,
        );
        templateIdMap[oldId] = newId;
      }

      // Vehicles
      for (var row in (data['vehicles'] as List)) {
        int oldId = row[columnId];
        row.remove(columnId);
        int newId = await txn.insert(
          tableVehicles,
          row as Map<String, dynamic>,
        );
        vehicleIdMap[oldId] = newId;
      }

      // Services
      for (var row in (data['services'] as List)) {
        int oldId = row[columnId];
        row.remove(columnId);
        // Update foreign keys
        row[columnVehicleId] = vehicleIdMap[row[columnVehicleId]];
        row[columnVendorId] = vendorIdMap[row[columnVendorId]];
        row[columnTemplateId] = templateIdMap[row[columnTemplateId]];

        int newId = await txn.insert(
          tableServices,
          row as Map<String, dynamic>,
        );
        serviceIdMap[oldId] = newId;
      }

      // Service Items
      for (var row in (data['service_items'] as List)) {
        row.remove(columnId);
        // Update foreign key
        row[columnServiceId] = serviceIdMap[row[columnServiceId]];
        await txn.insert(tableServiceItems, row as Map<String, dynamic>);
      }

      // Expenses
      for (var row in (data['expenses'] as List)) {
        row.remove(columnId);
        // Update foreign key
        row[columnVehicleId] = vehicleIdMap[row[columnVehicleId]];
        await txn.insert(tableExpenses, row as Map<String, dynamic>);
      }

      // Vehicle Papers
      if (data.containsKey('vehicle_papers')) {
        for (var row in (data['vehicle_papers'] as List)) {
          int oldId = row[columnId];
          row.remove(columnId);
          row[columnVehicleId] = vehicleIdMap[row[columnVehicleId]];

          // Handle File
          if (fileSourcePath != null &&
              row[columnFilePath] != null &&
              row[columnFilePath].isNotEmpty) {
            String oldPath = row[columnFilePath];
            String ext = extension(oldPath);
            String fileNameInZip = 'papers/paper_$oldId$ext';
            File sourceFile = File(join(fileSourcePath, fileNameInZip));
            if (await sourceFile.exists()) {
              String newFileName =
                  'paper_${DateTime.now().millisecondsSinceEpoch}_$oldId$ext';
              String newPath = join(appDocDir.path, newFileName);
              await sourceFile.copy(newPath);
              row[columnFilePath] = newPath;
            }
          }

          await txn.insert(tableVehiclePapers, row as Map<String, dynamic>);
        }
      }

      // Documents
      if (data.containsKey('documents')) {
        for (var row in (data['documents'] as List)) {
          int oldId = row[columnId];
          row.remove(columnId);
          if (row[columnVehicleId] != null) {
            row[columnVehicleId] = vehicleIdMap[row[columnVehicleId]];
          }

          // Handle File
          if (fileSourcePath != null &&
              row[columnFilePath] != null &&
              row[columnFilePath].isNotEmpty) {
            String oldPath = row[columnFilePath];
            String ext = extension(oldPath);
            String fileNameInZip = 'documents/doc_$oldId$ext';
            File sourceFile = File(join(fileSourcePath, fileNameInZip));
            if (await sourceFile.exists()) {
              String newFileName =
                  'doc_${DateTime.now().millisecondsSinceEpoch}_$oldId$ext';
              String newPath = join(appDocDir.path, newFileName);
              await sourceFile.copy(newPath);
              row[columnFilePath] = newPath;
            }
          }

          await txn.insert(tableDocuments, row as Map<String, dynamic>);
        }
      }

      // Reminders
      for (var row in (data['reminders'] as List)) {
        row.remove(columnId);
        // Update foreign keys
        row[columnVehicleId] = vehicleIdMap[row[columnVehicleId]];
        row[columnTemplateId] = templateIdMap[row[columnTemplateId]];
        await txn.insert(tableReminders, row as Map<String, dynamic>);
      }

      // Photos
      for (var row in (data['photos'] as List)) {
        int oldId = row[columnId]; // Save old ID for file lookup
        row.remove(columnId);
        // Update foreign keys (this is complex)
        if (row[columnParentType] == 'vehicle') {
          row[columnParentId] = vehicleIdMap[row[columnParentId]];
        } else if (row[columnParentType] == 'service') {
          row[columnParentId] = serviceIdMap[row[columnParentId]];
        }

        // Handle File
        if (fileSourcePath != null &&
            row[columnUri] != null &&
            row[columnUri].isNotEmpty) {
          String oldPath = row[columnUri];
          String ext = extension(oldPath);
          String fileNameInZip = 'photos/photo_$oldId$ext';
          File sourceFile = File(join(fileSourcePath, fileNameInZip));
          if (await sourceFile.exists()) {
            String newFileName =
                'photo_${DateTime.now().millisecondsSinceEpoch}_$oldId$ext';
            String newPath = join(appDocDir.path, newFileName);
            await sourceFile.copy(newPath);
            row[columnUri] = newPath;
          }
        }

        await txn.insert(tablePhotos, row as Map<String, dynamic>);
      }
    });
    print("Database restore complete.");
  }

  Future<bool> queryReminderExists(int vehicleId, int templateId) async {
    Database db = await instance.database;
    final result = await db.query(
      tableReminders,
      where: '$columnVehicleId = ? AND $columnTemplateId = ?',
      whereArgs: [vehicleId, templateId],
      limit: 1,
    );
    return result.isNotEmpty; // If the list is not empty, a reminder exists
  }

  Future<List<Map<String, dynamic>>> queryTemplateRemindersForVehicle(
    int vehicleId,
  ) async {
    Database db = await instance.database;
    return await db.query(
      tableReminders,
      where: '$columnVehicleId = ? AND $columnTemplateId IS NOT NULL',
      whereArgs: [vehicleId],
    );
  }

  Future<int> deleteRemindersByTemplate(int vehicleId, int templateId) async {
    Database db = await instance.database;
    return await db.delete(
      tableReminders,
      where: '$columnVehicleId = ? AND $columnTemplateId = ?',
      whereArgs: [vehicleId, templateId],
    );
  }

  Future<int> updateExpense(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableExpenses,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Deletes an expense by its ID
  Future<int> deleteExpense(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableExpenses,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> queryRemindersDueOn(String date) async {
    Database db = await instance.database;

    // This query JOINS with templates to get the name
    final String sql =
        '''
      SELECT 
        r.*, 
        t.$columnName AS template_name
      FROM $tableReminders r
      LEFT JOIN $tableServiceTemplates t ON r.$columnTemplateId = t.$columnId
      WHERE r.$columnVehicleId IS NOT NULL AND r.$columnDueDate = ?
    ''';

    return await db.rawQuery(sql, [date]);
  }

  Future<int> updateReminder(
    int id,
    String? newDueDate,
    int? newDueOdometer,
  ) async {
    Database db = await instance.database;
    return await db.update(
      tableReminders,
      {columnDueDate: newDueDate, columnDueOdometer: newDueOdometer},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<double> queryTotalSpendingForType(int vehicleId, String type) async {
    String tableName = (type == 'services') ? tableServices : tableExpenses;
    Database db = await instance.database;
    final totalResult = await db.rawQuery(
      'SELECT SUM($columnTotalCost) as total FROM $tableName WHERE $columnVehicleId = ?',
      [vehicleId],
    );

    double total = totalResult.isNotEmpty && totalResult.first['total'] != null
        ? (totalResult.first['total'] as num).toDouble()
        : 0.0;
    return total;
  }

  Future<List<String>> queryDistinctExpenseCategories() async {
    Database db = await instance.database;

    final List<Map<String, dynamic>> result = await db.query(
      tableExpenses,
      distinct: true,
      columns: [columnCategory],
      where: '$columnCategory IS NOT NULL AND $columnCategory != ?',
      whereArgs: [''], // Don't include empty strings
      orderBy: '$columnCategory ASC',
    );

    // Convert the list of maps into a simple list of strings
    return result.map((row) => row[columnCategory] as String).toList();
  }

  Future<int> updateVendor(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableVendors,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Deletes a vendor by its ID
  Future<int> deleteVendor(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableVendors,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateServiceTemplate(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableServiceTemplates,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Deletes a service template by its ID
  Future<int> deleteServiceTemplate(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableServiceTemplates,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePhotosForParent(int parentId, String parentType) async {
    Database db = await instance.database;
    return await db.delete(
      tablePhotos,
      where: '$columnParentId = ? AND $columnParentType = ?',
      whereArgs: [parentId, parentType],
    );
  }

  Future<int> deleteService(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableServices,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRemindersByService(int serviceId) async {
    Database db = await instance.database;
    return await db.delete(
      tableReminders,
      where: '$columnServiceId = ?',
      whereArgs: [serviceId],
    );
  }

  Future<List<Map<String, dynamic>>> queryServiceReport(int vehicleId) async {
    Database db = await instance.database;

    final String sql =
        '''
      SELECT 
        s.$columnId, 
        s.$columnServiceName,
        s.$columnServiceDate,
        s.$columnOdometer,
        si.$columnName AS part_name,
        si.$columnQty AS part_qty,
        si.$columnUnitCost AS part_cost,
        si.$columnTotalCost AS part_total,
        v.$columnName AS vendor_name,
        t.$columnName AS template_name
      FROM $tableServices s
      LEFT JOIN $tableServiceItems si ON si.$columnServiceId = s.$columnId
      LEFT JOIN $tableVendors v ON s.$columnVendorId = v.$columnId
      LEFT JOIN $tableServiceTemplates t ON si.$columnTemplateId = t.$columnId
      WHERE s.$columnVehicleId = ?
      ORDER BY s.$columnServiceDate DESC, s.$columnId, si.$columnId
    ''';

    return await db.rawQuery(sql, [vehicleId]);
  }

  Future<List<Map<String, dynamic>>> queryAllRemindersGroupedByVehicle() async {
    Database db = await instance.database;

    // This query gets all reminders, joins the vehicle name,
    // and joins the template name (if it exists)
    final String sql =
        '''
      SELECT 
        r.*,
        v.$columnMake, 
        v.$columnModel,
        v.$columnCurrentOdometer, 
        t.$columnName AS template_name
      FROM $tableReminders r
      JOIN $tableVehicles v ON v.$columnId = r.$columnVehicleId
      LEFT JOIN $tableServiceTemplates t ON t.$columnId = r.$columnTemplateId
      WHERE r.$columnStatus = 'pending'
      ORDER BY v.$columnMake, v.$columnModel, r.$columnDueDate ASC, r.$columnDueOdometer ASC
    ''';

    return await db.rawQuery(sql);
  }

  // Marks a single reminder as "completed"
  Future<int> updateReminderStatus(int id, String status) async {
    Database db = await instance.database;
    return await db.update(
      tableReminders,
      {columnStatus: status},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Finds all 'pending' reminders for a template and marks them as 'completed'
  // It also tags *which* service completed it
  Future<int> completeRemindersByTemplate(
    int vehicleId,
    int templateId,
    int serviceId,
  ) async {
    Database db = await instance.database;
    return await db.update(
      tableReminders,
      {columnStatus: 'completed', columnCompletedByServiceId: serviceId},
      where:
          '$columnVehicleId = ? AND $columnTemplateId = ? AND $columnStatus = ?',
      whereArgs: [vehicleId, templateId, 'pending'],
    );
  }

  // "Un-completes" any reminder that was completed by a specific service
  Future<int> uncompleteRemindersByService(int serviceId) async {
    Database db = await instance.database;
    return await db.update(
      tableReminders,
      {columnStatus: 'pending', columnCompletedByServiceId: null},
      where: '$columnCompletedByServiceId = ?',
      whereArgs: [serviceId],
    );
  }

  Future<List<Map<String, dynamic>>>
  queryAllPendingRemindersWithVehicle() async {
    Database db = await instance.database;
    final String sql =
        '''
    SELECT 
      r.*,
      v.$columnCurrentOdometer, 
      t.$columnName AS template_name
    FROM $tableReminders r
    JOIN $tableVehicles v ON v.$columnId = r.$columnVehicleId
    LEFT JOIN $tableServiceTemplates t ON t.$columnId = r.$columnTemplateId
    WHERE r.$columnStatus = 'pending'
  ''';
    return await db.rawQuery(sql);
  }

  // --- VEHICLE PAPERS-SPECIFIC METHODS ---

  Future<int> insertVehiclePaper(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableVehiclePapers, row);
  }

  Future<int> updateVehiclePaper(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableVehiclePapers,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteVehiclePaper(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableVehiclePapers,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Get all papers for a SINGLE vehicle
  Future<List<Map<String, dynamic>>> queryVehiclePapersForVehicle(
    int vehicleId,
  ) async {
    Database db = await instance.database;
    final String sql =
        '''
    SELECT 
      d.*,
      v.$columnMake, 
      v.$columnModel
    FROM $tableVehiclePapers d
    JOIN $tableVehicles v ON v.$columnId = d.$columnVehicleId
    WHERE d.$columnVehicleId = ?
    ORDER BY d.$columnPaperExpiryDate ASC
  ''';
    return await db.rawQuery(sql, [vehicleId]);
  }

  // Get papers expiring *on this day* for the notification task
  Future<List<Map<String, dynamic>>> queryVehiclePapersExpiringOn(
    String date,
  ) async {
    Database db = await instance.database;
    final String sql =
        '''
    SELECT 
      d.*,
      v.$columnMake, 
      v.$columnModel
    FROM $tableVehiclePapers d
    JOIN $tableVehicles v ON v.$columnId = d.$columnVehicleId
    WHERE d.$columnPaperExpiryDate = ?
  ''';
    return await db.rawQuery(sql, [date]);
  }

  // Gets a single vehicle paper by its ID
  Future<Map<String, dynamic>?> queryVehiclePaperById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      tableVehiclePapers,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> queryAllExpiringPapers() async {
    Database db = await instance.database;
    final String sql =
        '''
      SELECT 
        d.*,
        v.$columnMake, 
        v.$columnModel,
        v.$columnCurrentOdometer
      FROM $tableVehiclePapers d
      JOIN $tableVehicles v ON v.$columnId = d.$columnVehicleId
      WHERE d.$columnPaperExpiryDate IS NOT NULL AND d.$columnPaperExpiryDate != ''
      ORDER BY v.$columnMake, v.$columnModel, d.$columnPaperExpiryDate ASC
    ''';
    return await db.rawQuery(sql);
  }

  // --- DOCUMENT-SPECIFIC METHODS ---

  Future<int> insertGeneralDocument(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableDocuments, row);
  }

  Future<int> deleteGeneralDocument(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableDocuments,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Get all general documents, joined with vehicle info
  Future<List<Map<String, dynamic>>> queryAllGeneralDocuments() async {
    Database db = await instance.database;
    final String sql =
        '''
    SELECT 
      d.*,
      v.$columnMake, 
      v.$columnModel
    FROM $tableDocuments d
    LEFT JOIN $tableVehicles v ON v.$columnId = d.$columnVehicleId
    ORDER BY d.$columnId DESC
  ''';
    return await db.rawQuery(sql);
  }

  // Gets a single document by its ID
  Future<Map<String, dynamic>?> queryGeneralDocumentById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      tableDocuments,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}
