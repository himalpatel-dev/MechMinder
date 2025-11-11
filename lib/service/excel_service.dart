import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart'; // Make sure this path is correct
import 'settings_provider.dart'; // Make sure this path is correct

class ExcelService {
  final DatabaseHelper dbHelper;
  final SettingsProvider settings;

  ExcelService({required this.dbHelper, required this.settings});

  Future<String?> createExcelReport(int vehicleId, String vehicleName) async {
    try {
      // --- 1. Create the Excel File ---
      var excel = Excel.createExcel();

      // --- 2. Define Header Style ---
      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#EEEEEE"),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // --- 3. Build the "Services" Sheet ---
      Sheet serviceSheet = excel['Services'];
      excel.setDefaultSheet('Services');

      // Add Headers
      List<String> serviceHeaders = [
        'Service Date',
        'Odometer (${settings.unitType})',
        'Service Name',
        'Part Name',
        'Qty',
        'Part Cost (${settings.currencySymbol})',
        'Part Total (${settings.currencySymbol})',
        'Vendor',
      ];
      serviceSheet.appendRow(
        serviceHeaders.map((header) => TextCellValue(header)).toList(),
      );
      for (var i = 0; i < serviceHeaders.length; i++) {
        serviceSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        )..cellStyle = headerStyle;
        serviceSheet.setColumnAutoFit(i);
      }

      // --- 4. GET DATA AND BUILD GROUPED ROWS ---
      final serviceData = await dbHelper.queryServiceReport(vehicleId);

      int? lastServiceId; // This is our tracker

      for (var row in serviceData) {
        final currentServiceId = row[DatabaseHelper.columnId];

        // Check if this is a new service
        final bool isNewService = (currentServiceId != lastServiceId);

        if (isNewService && lastServiceId != null) {
          // Add a blank row for spacing
          serviceSheet.appendRow([]);
        }

        // --- THIS IS THE NEW LOGIC ---
        // We only add data to the first 3 and last columns
        // if it's the start of a new service group.
        serviceSheet.appendRow([
          isNewService
              ? TextCellValue(row[DatabaseHelper.columnServiceDate] ?? '')
              : null,
          isNewService
              ? TextCellValue(
                  (row[DatabaseHelper.columnOdometer] ?? '').toString(),
                )
              : null,
          isNewService
              ? TextCellValue(row[DatabaseHelper.columnServiceName] ?? '')
              : null,
          TextCellValue(row['part_name'] ?? 'N/A'), // This is always shown
          TextCellValue(
            (row['part_qty'] ?? '').toString(),
          ), // This is always shown
          TextCellValue(
            (row['part_cost'] ?? '').toString(),
          ), // This is always shown
          TextCellValue(
            (row['part_total'] ?? '').toString(),
          ), // This is always shown
          isNewService ? TextCellValue(row['vendor_name'] ?? 'N/A') : null,
        ]);
        // --- END OF NEW LOGIC ---

        // Update the tracker
        lastServiceId = currentServiceId;
      }

      // --- 5. Build the "Expenses" Sheet (Unchanged) ---
      Sheet expenseSheet = excel['Expenses'];
      List<String> expenseHeaders = [
        'Date',
        'Category',
        'Amount (${settings.currencySymbol})',
        'Notes',
      ];
      expenseSheet.appendRow(
        expenseHeaders.map((header) => TextCellValue(header)).toList(),
      );
      for (var i = 0; i < expenseHeaders.length; i++) {
        expenseSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        )..cellStyle = headerStyle;
        expenseSheet.setColumnAutoFit(i);
      }
      final expenseData = await dbHelper.queryExpensesForVehicle(vehicleId);
      for (var row in expenseData) {
        expenseSheet.appendRow([
          TextCellValue(row[DatabaseHelper.columnServiceDate] ?? ''),
          TextCellValue(row[DatabaseHelper.columnCategory] ?? ''),
          TextCellValue((row[DatabaseHelper.columnTotalCost] ?? '').toString()),
          TextCellValue(row[DatabaseHelper.columnNotes] ?? 'N/A'),
        ]);
      }

      // --- 6. Save and Share (Unchanged) ---
      List<int>? fileBytes = excel.save();
      if (fileBytes == null) {
        return 'Error: Could not save Excel file.';
      }

      final directory = await getTemporaryDirectory();
      String fileName = '${vehicleName.replaceAll(' ', '_')}_Report.xlsx';
      final filePath = '${directory.path}/$fileName';

      await File(filePath).writeAsBytes(fileBytes);
      print("Report file created at: $filePath");

      final xfile = XFile(filePath);
      await Share.shareXFiles([xfile], subject: '$vehicleName Service Report');

      return 'Report generated!'; // Success message
    } catch (e) {
      print("Error creating Excel report: $e");
      return "An error occurred: $e";
    }
  }
}
