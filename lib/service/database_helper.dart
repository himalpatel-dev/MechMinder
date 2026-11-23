import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'file_storage.dart';

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
  static const tableTodoList = 'todolist';

  // --- Common Column Names (unchanged) ---
  static const columnId = '_id';
  static const columnCreatedAt = 'created_at';
  static const columnUpdatedAt = 'updated_at';

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

  // --- TodoList Table Columns ---
  static const columnPartName = 'part_name';

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
      onUpgrade: _onUpgrade,
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
        $columnCreatedAt TEXT DEFAULT (datetime('now', 'localtime')),
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

    // --- TodoList Table ---
    await db.execute('''
      CREATE TABLE $tableTodoList (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnVehicleId INTEGER NOT NULL,
        $columnPartName TEXT NOT NULL,
        $columnNotes TEXT,
        $columnStatus TEXT NOT NULL DEFAULT 'pending',
        $columnCreatedAt TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        $columnUpdatedAt TEXT,
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
    await db.execute(
      'CREATE INDEX idx_papers_created_at ON $tableVehiclePapers ($columnCreatedAt)',
    );

    // 7. Photos
    await db.execute(
      'CREATE INDEX idx_photos_parent ON $tablePhotos ($columnParentId, $columnParentType)',
    );

    // 8. Documents
    await db.execute(
      'CREATE INDEX idx_documents_vehicle_id ON $tableDocuments ($columnVehicleId)',
    );

    // 9. TodoList
    await db.execute(
      'CREATE INDEX idx_todolist_vehicle_id ON $tableTodoList ($columnVehicleId)',
    );
    await db.execute(
      'CREATE INDEX idx_todolist_status ON $tableTodoList ($columnStatus)',
    );
  }

  // --- _onUpgrade (RESTORED) ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version 2: Add created_at column to vehicle_papers
      // We check if column exists first to be safe, though not strictly necessary if versioning is correct
      // SQLite doesn't support IF NOT EXISTS for columns in ALTER TABLE directly in all versions,
      // but since we control the version, we can assume it's needed.
      try {
        await db.execute(
          'ALTER TABLE $tableVehiclePapers ADD COLUMN $columnCreatedAt TEXT DEFAULT (datetime(\'now\', \'localtime\'))',
        );
        // Add index for the new column
        await db.execute(
          'CREATE INDEX idx_papers_created_at ON $tableVehiclePapers ($columnCreatedAt)',
        );
      } catch (e) {
        // Column might already exist if user had a dev build
        print("Error adding column created_at: $e");
      }
    }

    if (oldVersion < 3) {
      // Version 3: Add updated_at column to todolist
      try {
        await db.execute(
          'ALTER TABLE $tableTodoList ADD COLUMN $columnUpdatedAt TEXT',
        );
      } catch (e) {
        // Column might already exist if user had a dev build
        print("Error adding column updated_at to todolist: $e");
      }
    }
  }

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

    // 3. Get total from Papers
    // Use created_at as the transaction date
    String paperWhere = '$columnVehicleId = ?';
    List<dynamic> paperArgs = [vehicleId];

    if (startDate != null && endDate != null) {
      // Assuming created_at is stored as 'YYYY-MM-DD...' string
      // We only compare the date part
      paperWhere += ' AND date($columnCreatedAt) BETWEEN ? AND ?';
      paperArgs.addAll([startDate, endDate]);
    }

    final paperTotalResult = await db.rawQuery(
      'SELECT SUM($columnCost) as total FROM $tableVehiclePapers WHERE $paperWhere',
      paperArgs,
    );
    double paperTotal =
        paperTotalResult.isNotEmpty && paperTotalResult.first['total'] != null
        ? (paperTotalResult.first['total'] as num).toDouble()
        : 0.0;

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

    // 1. Get spending from Expenses, grouped by category.
    // COALESCE: SUM() is NULL when every cost in a group is empty, and the
    // charts expect a number.
    final categoryResult = await db.rawQuery(
      'SELECT $columnCategory, COALESCE(SUM($columnTotalCost), 0) as total FROM $tableExpenses WHERE $expenseWhere GROUP BY $columnCategory',
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

    // 3. Get total from Papers
    String paperWhere = '$columnVehicleId = ?';
    List<dynamic> paperArgs = [vehicleId];

    if (startDate != null && endDate != null) {
      paperWhere += ' AND date($columnCreatedAt) BETWEEN ? AND ?';
      paperArgs.addAll([startDate, endDate]);
    }

    final paperResult = await db.rawQuery(
      'SELECT $columnPaperType, COALESCE(SUM($columnCost), 0) as total FROM $tableVehiclePapers WHERE $paperWhere GROUP BY $columnPaperType',
      paperArgs,
    );
    // Add papers to results, treating paper type as category
    for (var row in paperResult) {
      results.add({
        DatabaseHelper.columnCategory: row[DatabaseHelper.columnPaperType],
        'total': row['total'],
      });
    }

    if (serviceTotal > 0) {
      results.add({
        DatabaseHelper.columnCategory: 'Services', // Add a custom category
        'total': serviceTotal,
      });
    }

    // Zero-cost groups add nothing to the chart and would draw empty slices.
    return results.where((r) => ((r['total'] as num?) ?? 0) > 0).toList();
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
  // "ON DELETE CASCADE" removes its services, items, reminders, expenses,
  // papers, documents and to-dos. The photos table has no foreign key, so its
  // rows (vehicle photos and service bill photos) are removed here explicitly;
  // leftover photo rows used to make every later backup impossible to restore.
  Future<int> deleteVehicle(int id) async {
    Database db = await instance.database;
    final List<String> filePaths = [];

    final count = await db.transaction((txn) async {
      const photoWhere =
          "($columnParentType = 'vehicle' AND $columnParentId = ?) OR "
          "($columnParentType = 'service' AND $columnParentId IN "
          "(SELECT $columnId FROM $tableServices WHERE $columnVehicleId = ?))";

      final photos = await txn.query(
        tablePhotos,
        columns: [columnUri],
        where: photoWhere,
        whereArgs: [id, id],
      );
      filePaths.addAll(photos.map((r) => r[columnUri] as String? ?? ''));

      final papers = await txn.query(
        tableVehiclePapers,
        columns: [columnFilePath],
        where: '$columnVehicleId = ?',
        whereArgs: [id],
      );
      filePaths.addAll(papers.map((r) => r[columnFilePath] as String? ?? ''));

      final documents = await txn.query(
        tableDocuments,
        columns: [columnFilePath],
        where: '$columnVehicleId = ?',
        whereArgs: [id],
      );
      filePaths.addAll(
        documents.map((r) => r[columnFilePath] as String? ?? ''),
      );

      await txn.delete(tablePhotos, where: photoWhere, whereArgs: [id, id]);
      return txn.delete(tableVehicles, where: '$columnId = ?', whereArgs: [id]);
    });

    await _deleteFilesIfUnreferenced(filePaths);
    return count;
  }

  /// Deletes files from app storage unless another photo, paper or document
  /// row still points at them. (Older versions could give two papers the same
  /// file, so a path is checked before its file is removed.)
  Future<void> _deleteFilesIfUnreferenced(Iterable<String> paths) async {
    final unique = paths.where((p) => p.isNotEmpty).toSet();
    if (unique.isEmpty) return;
    final db = await instance.database;
    final toDelete = <String>[];
    for (final path in unique) {
      final refs = await db.rawQuery(
        '''
        SELECT 1 FROM $tablePhotos WHERE $columnUri = ?
        UNION ALL SELECT 1 FROM $tableVehiclePapers WHERE $columnFilePath = ?
        UNION ALL SELECT 1 FROM $tableDocuments WHERE $columnFilePath = ?
        LIMIT 1
        ''',
        [path, path, path],
      );
      if (refs.isEmpty) toDelete.add(path);
    }
    await FileStorage.deleteOwnedFiles(toDelete);
  }

  /// Removes photo rows whose vehicle or service no longer exists (left
  /// behind by older versions when a vehicle was deleted), and their files.
  Future<void> deleteOrphanPhotos() async {
    final db = await instance.database;
    const orphanWhere =
        "($columnParentType = 'vehicle' AND $columnParentId NOT IN (SELECT $columnId FROM $tableVehicles)) OR "
        "($columnParentType = 'service' AND $columnParentId NOT IN (SELECT $columnId FROM $tableServices))";
    final rows = await db.query(
      tablePhotos,
      columns: [columnUri],
      where: orphanWhere,
    );
    if (rows.isEmpty) return;
    await db.delete(tablePhotos, where: orphanWhere);
    await _deleteFilesIfUnreferenced(
      rows.map((r) => r[columnUri] as String? ?? ''),
    );
  }

  /// Older versions saved the image picker's cache path, which Android can
  /// clear. Copies every photo that still exists outside app storage into
  /// app storage and updates its row. Safe to run on every launch.
  Future<void> moveExternalPhotosToAppStorage() async {
    final db = await instance.database;
    final rows = await db.query(tablePhotos, columns: [columnId, columnUri]);
    for (final row in rows) {
      final uri = row[columnUri] as String?;
      if (uri == null || uri.isEmpty) continue;
      if (await FileStorage.isOwned(uri)) continue;
      if (!await File(uri).exists()) continue;
      try {
        final newPath = await FileStorage.importFile(
          uri,
          FileStorage.photosFolder,
        );
        await db.update(
          tablePhotos,
          {columnUri: newPath},
          where: '$columnId = ?',
          whereArgs: [row[columnId]],
        );
      } catch (e) {
        print('Could not move photo $uri: $e');
      }
    }
  }

  /// Template ids used by a service's parts.
  Future<Set<int>> _templateIdsForService(
    DatabaseExecutor exec,
    int serviceId,
  ) async {
    final rows = await exec.query(
      tableServiceItems,
      columns: [columnTemplateId],
      where: '$columnServiceId = ? AND $columnTemplateId IS NOT NULL',
      whereArgs: [serviceId],
    );
    return rows.map((r) => r[columnTemplateId] as int).toSet();
  }

  /// Recomputes which reminders for one part (template) on one vehicle are
  /// pending or completed, from the service history:
  ///
  /// * A reminder created by service S is completed by the next service
  ///   (by date, then id) that also includes this part, or pending if there
  ///   is none. So editing an old service never overrides the newest
  ///   reminder, and deleting the newest service brings the previous
  ///   reminder back.
  /// * A reminder not created by a service keeps its completion only while
  ///   the completing service still includes the part.
  Future<void> _recomputeTemplateChain(
    DatabaseExecutor exec,
    int vehicleId,
    int templateId,
  ) async {
    final services = await exec.rawQuery(
      '''
      SELECT DISTINCT s.$columnId AS id, s.$columnServiceDate AS d
      FROM $tableServices s
      JOIN $tableServiceItems si ON si.$columnServiceId = s.$columnId
      WHERE s.$columnVehicleId = ? AND si.$columnTemplateId = ?
      ORDER BY s.$columnServiceDate ASC, s.$columnId ASC
      ''',
      [vehicleId, templateId],
    );
    final order = services.map((r) => r['id'] as int).toList();

    final reminders = await exec.query(
      tableReminders,
      where: '$columnVehicleId = ? AND $columnTemplateId = ?',
      whereArgs: [vehicleId, templateId],
    );

    for (final r in reminders) {
      final int? source = r[columnServiceId] as int?;
      final int? currentBy = r[columnCompletedByServiceId] as int?;
      int? completedBy;

      if (source != null) {
        final index = order.indexOf(source);
        // Source service no longer has this part: leave legacy rows alone.
        if (index == -1) continue;
        completedBy = index + 1 < order.length ? order[index + 1] : null;
      } else {
        completedBy = (currentBy != null && order.contains(currentBy))
            ? currentBy
            : null;
      }

      final newStatus = completedBy == null ? 'pending' : 'completed';
      if (newStatus != r[columnStatus] || completedBy != currentBy) {
        await exec.update(
          tableReminders,
          {columnStatus: newStatus, columnCompletedByServiceId: completedBy},
          where: '$columnId = ?',
          whereArgs: [r[columnId]],
        );
      }
    }
  }

  /// "2026-01-31" + 30 days, computed on calendar dates so daylight-saving
  /// changes can't shift the result by a day.
  static String _addDays(String isoDate, int days) {
    final d = DateTime.parse(isoDate);
    final result = DateTime(d.year, d.month, d.day + days);
    return result.toIso8601String().split('T')[0];
  }

  /// Saves a service, its parts, its reminders and new photos in one
  /// transaction: either everything is written or nothing is.
  ///
  /// [serviceRow] holds the service columns (without the id). [items] hold
  /// service_items columns (without id/service id). [newPhotoPaths] must
  /// already be in app storage. Returns the service id.
  Future<int> saveServiceWithItems({
    int? serviceId,
    required Map<String, dynamic> serviceRow,
    required List<Map<String, dynamic>> items,
    required List<String> newPhotoPaths,
  }) async {
    final db = await instance.database;
    return db.transaction((txn) async {
      final int vehicleId = serviceRow[columnVehicleId] as int;
      int id;
      Set<int> oldTemplateIds = {};

      if (serviceId == null) {
        id = await txn.insert(tableServices, serviceRow);
      } else {
        id = serviceId;
        oldTemplateIds = await _templateIdsForService(txn, id);
        await txn.update(
          tableServices,
          serviceRow,
          where: '$columnId = ?',
          whereArgs: [id],
        );
      }

      // Reminders this service created are rebuilt below.
      await txn.delete(
        tableReminders,
        where: '$columnServiceId = ?',
        whereArgs: [id],
      );

      await txn.delete(
        tableServiceItems,
        where: '$columnServiceId = ?',
        whereArgs: [id],
      );
      final Set<int> newTemplateIds = {};
      for (final item in items) {
        await txn.insert(tableServiceItems, {...item, columnServiceId: id});
        final templateId = item[columnTemplateId] as int?;
        if (templateId != null) newTemplateIds.add(templateId);
      }

      // Raise the vehicle's odometer if this service shows a higher reading.
      final int? odometer = serviceRow[columnOdometer] as int?;
      if (odometer != null) {
        await txn.rawUpdate(
          '''
          UPDATE $tableVehicles
          SET $columnCurrentOdometer = ?, $columnOdometerUpdatedAt = ?
          WHERE $columnId = ? AND ($columnCurrentOdometer IS NULL OR $columnCurrentOdometer < ?)
          ''',
          [odometer, DateTime.now().toIso8601String(), vehicleId, odometer],
        );
      }

      final String serviceDate = serviceRow[columnServiceDate] as String;
      for (final templateId in newTemplateIds) {
        final template = await txn.query(
          tableServiceTemplates,
          where: '$columnId = ?',
          whereArgs: [templateId],
          limit: 1,
        );
        if (template.isNotEmpty) {
          final int? intervalDays = template.first[columnIntervalDays] as int?;
          final int? intervalKm = template.first[columnIntervalKm] as int?;
          // 0 means "no interval" on the Auto Parts screen, so only > 0
          // creates a due date or due odometer.
          final String? nextDueDate = (intervalDays != null && intervalDays > 0)
              ? _addDays(serviceDate, intervalDays)
              : null;
          final int? nextDueOdometer =
              (intervalKm != null && intervalKm > 0 && odometer != null)
              ? odometer + intervalKm
              : null;
          if (nextDueDate != null || nextDueOdometer != null) {
            await txn.insert(tableReminders, {
              columnVehicleId: vehicleId,
              columnServiceId: id,
              columnTemplateId: templateId,
              columnDueDate: nextDueDate,
              columnDueOdometer: nextDueOdometer,
              columnStatus: 'pending',
            });
          }
        }

        // Reminders not created by a service are completed by this one.
        await txn.update(
          tableReminders,
          {columnStatus: 'completed', columnCompletedByServiceId: id},
          where:
              '$columnVehicleId = ? AND $columnTemplateId = ? AND $columnStatus = ? AND $columnServiceId IS NULL',
          whereArgs: [vehicleId, templateId, 'pending'],
        );
      }

      for (final templateId in {...oldTemplateIds, ...newTemplateIds}) {
        await _recomputeTemplateChain(txn, vehicleId, templateId);
      }

      for (final path in newPhotoPaths) {
        await txn.insert(tablePhotos, {
          columnParentId: id,
          columnParentType: 'service',
          columnUri: path,
        });
      }
      return id;
    });
  }

  /// Deletes a service with its parts, the reminders it created and its
  /// photos, then repairs the reminder chain so the previous service's
  /// reminder becomes pending again.
  Future<void> deleteServiceFully(int serviceId) async {
    final db = await instance.database;
    final List<String> photoPaths = [];

    await db.transaction((txn) async {
      final service = await txn.query(
        tableServices,
        columns: [columnVehicleId],
        where: '$columnId = ?',
        whereArgs: [serviceId],
        limit: 1,
      );
      if (service.isEmpty) return;
      final int vehicleId = service.first[columnVehicleId] as int;

      final templateIds = await _templateIdsForService(txn, serviceId);
      final completedByThis = await txn.query(
        tableReminders,
        columns: [columnTemplateId],
        where:
            '$columnCompletedByServiceId = ? AND $columnTemplateId IS NOT NULL',
        whereArgs: [serviceId],
      );
      templateIds.addAll(
        completedByThis.map((r) => r[columnTemplateId] as int),
      );

      final photos = await txn.query(
        tablePhotos,
        columns: [columnUri],
        where: "$columnParentType = 'service' AND $columnParentId = ?",
        whereArgs: [serviceId],
      );
      photoPaths.addAll(photos.map((r) => r[columnUri] as String? ?? ''));
      await txn.delete(
        tablePhotos,
        where: "$columnParentType = 'service' AND $columnParentId = ?",
        whereArgs: [serviceId],
      );

      await txn.delete(
        tableReminders,
        where: '$columnServiceId = ?',
        whereArgs: [serviceId],
      );
      // Anything it completed goes back to pending (recompute may complete
      // it again if a later service also has the part).
      await txn.update(
        tableReminders,
        {columnStatus: 'pending', columnCompletedByServiceId: null},
        where: '$columnCompletedByServiceId = ?',
        whereArgs: [serviceId],
      );
      await txn.delete(
        tableServiceItems,
        where: '$columnServiceId = ?',
        whereArgs: [serviceId],
      );
      await txn.delete(
        tableServices,
        where: '$columnId = ?',
        whereArgs: [serviceId],
      );

      for (final templateId in templateIds) {
        await _recomputeTemplateChain(txn, vehicleId, templateId);
      }
    });

    await _deleteFilesIfUnreferenced(photoPaths);
  }

  /// Saves a vehicle and its new photos together. Returns the vehicle id.
  Future<int> saveVehicleWithPhotos({
    required Map<String, dynamic> vehicleRow,
    required List<String> newPhotoPaths,
  }) async {
    final db = await instance.database;
    return db.transaction((txn) async {
      int id;
      if (vehicleRow[columnId] != null) {
        id = vehicleRow[columnId] as int;
        await txn.update(
          tableVehicles,
          vehicleRow,
          where: '$columnId = ?',
          whereArgs: [id],
        );
      } else {
        id = await txn.insert(tableVehicles, vehicleRow);
      }
      for (final path in newPhotoPaths) {
        await txn.insert(tablePhotos, {
          columnParentId: id,
          columnParentType: 'vehicle',
          columnUri: path,
        });
      }
      return id;
    });
  }

  /// Deletes photo rows by id, then their files if nothing else uses them.
  Future<void> deletePhotosByIds(Iterable<int> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(idList.length, '?').join(',');
    final rows = await db.query(
      tablePhotos,
      columns: [columnUri],
      where: '$columnId IN ($placeholders)',
      whereArgs: idList,
    );
    await db.delete(
      tablePhotos,
      where: '$columnId IN ($placeholders)',
      whereArgs: idList,
    );
    await _deleteFilesIfUnreferenced(
      rows.map((r) => r[columnUri] as String? ?? ''),
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

    // Files used by the data that is about to be wiped. They are removed only
    // after the restore succeeds, and only if the restored data doesn't use
    // them (a JSON-only restore keeps the old paths).
    final List<String> oldFiles = [
      for (final r in await db.query(tablePhotos, columns: [columnUri]))
        r[columnUri] as String? ?? '',
      for (final r in await db.query(
        tableVehiclePapers,
        columns: [columnFilePath],
      ))
        r[columnFilePath] as String? ?? '',
      for (final r in await db.query(tableDocuments, columns: [columnFilePath]))
        r[columnFilePath] as String? ?? '',
    ];
    // Files copied in by this restore; deleted again if it fails.
    final List<String> copiedFiles = [];

    Future<String?> copyFromBackup(String fileNameInZip, String newName) async {
      if (fileSourcePath == null) return null;
      final source = File(join(fileSourcePath, fileNameInZip));
      if (!await source.exists()) return null;
      final newPath = join(appDocDir.path, newName);
      await source.copy(newPath);
      copiedFiles.add(newPath);
      return newPath;
    }

    List<dynamic> rowsOf(String key) => (data[key] as List?) ?? const [];

    // We must use a "transaction" so if *any* part fails,
    // the whole thing is rolled back.
    try {
      await _restoreInTransaction(db, rowsOf, copyFromBackup);
    } catch (e) {
      await FileStorage.deleteOwnedFiles(copiedFiles);
      rethrow;
    }
    await _deleteFilesIfUnreferenced(oldFiles);
    print("Database restore complete.");
  }

  Future<void> _restoreInTransaction(
    Database db,
    List<dynamic> Function(String key) rowsOf,
    Future<String?> Function(String fileNameInZip, String newName)
    copyFromBackup,
  ) async {
    await db.transaction((txn) async {
      // --- 1. WIPE ALL CURRENT DATA (in correct order) ---
      await txn.delete(tableDocuments); // Wipe last
      await txn.delete(tableVehiclePapers); // Wipe last
      await txn.delete(tableTodoList); // Wipe todolist
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

      // Rows whose vehicle or service is missing from the backup (left behind
      // by older versions) are skipped instead of failing the whole restore.

      // Vendors
      for (var row in rowsOf('vendors')) {
        int oldId = row[columnId];
        row.remove(columnId); // Remove old ID
        int newId = await txn.insert(tableVendors, row as Map<String, dynamic>);
        vendorIdMap[oldId] = newId;
      }

      // Templates
      for (var row in rowsOf('service_templates')) {
        int oldId = row[columnId];
        row.remove(columnId);
        int newId = await txn.insert(
          tableServiceTemplates,
          row as Map<String, dynamic>,
        );
        templateIdMap[oldId] = newId;
      }

      // Vehicles
      for (var row in rowsOf('vehicles')) {
        int oldId = row[columnId];
        row.remove(columnId);
        int newId = await txn.insert(
          tableVehicles,
          row as Map<String, dynamic>,
        );
        vehicleIdMap[oldId] = newId;
      }

      // Services
      for (var row in rowsOf('services')) {
        int oldId = row[columnId];
        final int? vehicleId = vehicleIdMap[row[columnVehicleId]];
        if (vehicleId == null) continue;
        row.remove(columnId);
        // Update foreign keys
        row[columnVehicleId] = vehicleId;
        row[columnVendorId] = vendorIdMap[row[columnVendorId]];
        row[columnTemplateId] = templateIdMap[row[columnTemplateId]];

        int newId = await txn.insert(
          tableServices,
          row as Map<String, dynamic>,
        );
        serviceIdMap[oldId] = newId;
      }

      // Service Items
      for (var row in rowsOf('service_items')) {
        final int? serviceId = serviceIdMap[row[columnServiceId]];
        if (serviceId == null) continue;
        row.remove(columnId);
        // Update foreign keys
        row[columnServiceId] = serviceId;
        row[columnTemplateId] = templateIdMap[row[columnTemplateId]];
        await txn.insert(tableServiceItems, row as Map<String, dynamic>);
      }

      // Expenses
      for (var row in rowsOf('expenses')) {
        final int? vehicleId = vehicleIdMap[row[columnVehicleId]];
        if (vehicleId == null) continue;
        row.remove(columnId);
        row[columnVehicleId] = vehicleId;
        await txn.insert(tableExpenses, row as Map<String, dynamic>);
      }

      // Vehicle Papers
      for (var row in rowsOf('vehicle_papers')) {
        int oldId = row[columnId];
        final int? vehicleId = vehicleIdMap[row[columnVehicleId]];
        if (vehicleId == null) continue;
        row.remove(columnId);
        row[columnVehicleId] = vehicleId;

        final String? oldPath = row[columnFilePath];
        if (oldPath != null && oldPath.isNotEmpty) {
          String ext = extension(oldPath);
          final newPath = await copyFromBackup(
            'papers/paper_$oldId$ext',
            'paper_${DateTime.now().millisecondsSinceEpoch}_$oldId$ext',
          );
          if (newPath != null) row[columnFilePath] = newPath;
        }

        await txn.insert(tableVehiclePapers, row as Map<String, dynamic>);
      }

      // Documents (vehicle is optional)
      for (var row in rowsOf('documents')) {
        int oldId = row[columnId];
        row.remove(columnId);
        if (row[columnVehicleId] != null) {
          row[columnVehicleId] = vehicleIdMap[row[columnVehicleId]];
        }

        final String? oldPath = row[columnFilePath];
        if (oldPath != null && oldPath.isNotEmpty) {
          String ext = extension(oldPath);
          final newPath = await copyFromBackup(
            'documents/doc_$oldId$ext',
            'doc_${DateTime.now().millisecondsSinceEpoch}_$oldId$ext',
          );
          if (newPath != null) row[columnFilePath] = newPath;
        }

        await txn.insert(tableDocuments, row as Map<String, dynamic>);
      }

      // Reminders: point their service links at the new service ids, or
      // editing a restored service would change other services' reminders.
      for (var row in rowsOf('reminders')) {
        final int? vehicleId = vehicleIdMap[row[columnVehicleId]];
        if (vehicleId == null) continue;
        row.remove(columnId);
        row[columnVehicleId] = vehicleId;
        row[columnTemplateId] = templateIdMap[row[columnTemplateId]];
        row[columnServiceId] = serviceIdMap[row[columnServiceId]];
        row[columnCompletedByServiceId] =
            serviceIdMap[row[columnCompletedByServiceId]];
        await txn.insert(tableReminders, row as Map<String, dynamic>);
      }

      // TodoList
      for (var row in rowsOf('todolist')) {
        final int? vehicleId = vehicleIdMap[row[columnVehicleId]];
        if (vehicleId == null) continue;
        row.remove(columnId);
        row[columnVehicleId] = vehicleId;
        await txn.insert(tableTodoList, row as Map<String, dynamic>);
      }

      // Photos
      for (var row in rowsOf('photos')) {
        int oldId = row[columnId]; // Save old ID for file lookup
        int? parentId;
        if (row[columnParentType] == 'vehicle') {
          parentId = vehicleIdMap[row[columnParentId]];
        } else if (row[columnParentType] == 'service') {
          parentId = serviceIdMap[row[columnParentId]];
        }
        // Orphan photo (its vehicle/service was deleted): skip it.
        if (parentId == null) continue;
        row.remove(columnId);
        row[columnParentId] = parentId;

        final String? oldPath = row[columnUri];
        if (oldPath != null && oldPath.isNotEmpty) {
          String ext = extension(oldPath);
          final newPath = await copyFromBackup(
            'photos/photo_$oldId$ext',
            'photo_${DateTime.now().millisecondsSinceEpoch}_$oldId$ext',
          );
          if (newPath != null) row[columnUri] = newPath;
        }

        await txn.insert(tablePhotos, row as Map<String, dynamic>);
      }
    });
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
      {
        columnDueDate: newDueDate,
        columnDueOdometer: newDueOdometer,
        // New due point: notify again from the start.
        columnLastNotifiedAt: null,
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  /// Records which notification stage was last shown for a reminder.
  /// Stored as "YYYY-MM-DD|stage" in last_notified_at.
  Future<int> updateReminderLastNotified(int id, String value) async {
    Database db = await instance.database;
    return await db.update(
      tableReminders,
      {columnLastNotifiedAt: value},
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
      v.$columnMake,
      v.$columnModel,
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

  /// Deletes a paper and its attached file, unless another row still uses
  /// that file (older versions could give two papers the same file).
  Future<void> deleteVehiclePaperWithFile(int id) async {
    final paper = await queryVehiclePaperById(id);
    await deleteVehiclePaper(id);
    final path = paper?[columnFilePath] as String?;
    if (path != null) await _deleteFilesIfUnreferenced([path]);
  }

  /// Deletes a general document and its file (if nothing else uses it).
  Future<void> deleteGeneralDocumentWithFile(int id) async {
    final doc = await queryGeneralDocumentById(id);
    await deleteGeneralDocument(id);
    final path = doc?[columnFilePath] as String?;
    if (path != null) await _deleteFilesIfUnreferenced([path]);
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

  // --- TodoList CRUD Functions ---

  // Insert a new todo item
  Future<int> insertTodoItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableTodoList, row);
  }

  // Get all pending todo items across all vehicles
  Future<List<Map<String, dynamic>>> queryAllPendingTodos() async {
    Database db = await instance.database;
    final String sql =
        '''
      SELECT 
        t.*,
        v.$columnMake,
        v.$columnModel,
        v.$columnRegNo
      FROM $tableTodoList t
      LEFT JOIN $tableVehicles v ON v.$columnId = t.$columnVehicleId
      WHERE t.$columnStatus = 'pending'
      ORDER BY t.$columnCreatedAt DESC
    ''';
    return await db.rawQuery(sql);
  }

  // Get all todo items for a specific vehicle
  Future<List<Map<String, dynamic>>> queryTodosForVehicle(int vehicleId) async {
    Database db = await instance.database;
    return await db.query(
      tableTodoList,
      where: '$columnVehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: '$columnCreatedAt DESC',
    );
  }

  // Get all completed todo items across all vehicles
  Future<List<Map<String, dynamic>>> queryAllCompletedTodos() async {
    Database db = await instance.database;
    final String sql =
        '''
      SELECT 
        t.*,
        v.$columnMake,
        v.$columnModel,
        v.$columnRegNo
      FROM $tableTodoList t
      LEFT JOIN $tableVehicles v ON v.$columnId = t.$columnVehicleId
      WHERE t.$columnStatus = 'completed'
      ORDER BY t.$columnUpdatedAt DESC, t.$columnCreatedAt DESC
    ''';
    return await db.rawQuery(sql);
  }

  // Update todo status (pending/completed)
  Future<int> updateTodoStatus(int id, String status) async {
    Database db = await instance.database;

    // Prepare the update map
    Map<String, dynamic> updateData = {columnStatus: status};

    // If marking as completed, set the updated_at timestamp
    if (status == 'completed') {
      updateData[columnUpdatedAt] = DateTime.now().toIso8601String();
    }

    return await db.update(
      tableTodoList,
      updateData,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Delete a todo item
  Future<int> deleteTodoItem(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableTodoList,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Update a todo item
  Future<int> updateTodoItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(
      tableTodoList,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}
