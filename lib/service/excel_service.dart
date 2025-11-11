import 'dart:io';
import 'package:excel/excel.dart';
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
      
      // --- 2. Define Styles ---
      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#EEEEEE"), // Using your preferred syntax
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      CellStyle totalStyle = CellStyle(
        bold: true, 
        fontSize: 12, 
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center
      );
      
      // --- 3. Define the new Data Style ---
      CellStyle dataStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      
      // --- 4. Build the "Services" Sheet ---
      Sheet serviceSheet = excel['Services'];
      excel.setDefaultSheet('Services');

      // Add Headers
      List<String> serviceHeaders = [
        'Sr. No.',
        'Service Date',
        'Odometer (${settings.unitType})',
        'Service Name',
        'Vendor',
        'Part Name',
        'Qty',
        'Part Cost (${settings.currencySymbol})',
        'Part Total (${settings.currencySymbol})',       
      ];
      serviceSheet.appendRow(serviceHeaders.map((header) => TextCellValue(header)).toList());
      for (var i = 0; i < serviceHeaders.length; i++) {
        serviceSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..cellStyle = headerStyle;
        serviceSheet.setColumnAutoFit(i); // Your correct syntax
      }
      
      // --- 5. GET DATA AND BUILD GROUPED ROWS ---
      final serviceData = await dbHelper.queryServiceReport(vehicleId);
      
      int? lastServiceId;
      int serialNumber = 0;
      double serviceGrandTotal = 0.0;
      
      // --- THIS IS THE FIX: Track which rows are data rows ---
      List<int> dataRowIndexes = [];

      for (int i = 0; i < serviceData.length; i++) {
        final row = serviceData[i];
        final currentServiceId = row[DatabaseHelper.columnId];
        final bool isNewService = (currentServiceId != lastServiceId);

        if (isNewService) {
          if (lastServiceId != null) {
            serviceSheet.appendRow([TextCellValue('')]); // Blank row
          }
          serialNumber++; 
          
          // Add the first row of the service
          dataRowIndexes.add(serviceSheet.maxRows); // Track this row index
          serviceSheet.appendRow([
            TextCellValue(serialNumber.toString()),
            TextCellValue(row[DatabaseHelper.columnServiceDate] ?? ''),
            TextCellValue((row[DatabaseHelper.columnOdometer] ?? '').toString()),
            TextCellValue(row[DatabaseHelper.columnServiceName] ?? ''),
            TextCellValue(row['vendor_name'] ?? 'N/A'),
            TextCellValue(row['part_name'] ?? 'N/A'), // Part 1
            TextCellValue((row['part_qty'] ?? '').toString()),
            TextCellValue((row['part_cost'] ?? '').toString()),
            TextCellValue((row['part_total'] ?? '').toString()),            
          ]);
        } else {
          // Add the subsequent part row
          dataRowIndexes.add(serviceSheet.maxRows); // Track this row index
          serviceSheet.appendRow([
            null, null, null, null, null,
            TextCellValue(row['part_name'] ?? 'N/A'), // Part 2, 3, etc.
            TextCellValue((row['part_qty'] ?? '').toString()),
            TextCellValue((row['part_cost'] ?? '').toString()),
            TextCellValue((row['part_total'] ?? '').toString()),            
          ]);
        }
        
        double? partTotal = double.tryParse((row['part_total'] ?? '0').toString());
        if(partTotal != null) {
          serviceGrandTotal += partTotal;
        }
        
        lastServiceId = currentServiceId;
      }
      
      // Add Total Row for Services
      serviceSheet.appendRow([]); // Blank row
      serviceSheet.appendRow([
        null, null, null, null, null, null,null,
        TextCellValue('Total:'),
        TextCellValue('${settings.currencySymbol}${serviceGrandTotal.toStringAsFixed(2)}'),
        
      ]);
      serviceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: serviceSheet.maxRows - 1))
        ..cellStyle = totalStyle;
      serviceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: serviceSheet.maxRows - 1))
        ..cellStyle = totalStyle;

      // --- THIS IS THE FIX ---
      // 6. Apply the dataStyle to all data rows we tracked
      for (int r in dataRowIndexes) {
        for (int c = 0; c < serviceHeaders.length; c++) {
          final cell = serviceSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
          // Apply the style to all cells in that row
          cell.cellStyle = dataStyle;
        }
      }
      // --- END OF FIX ---
      
      // --- 7. Build the "Expenses" Sheet ---
      Sheet expenseSheet = excel['Expenses'];
      List<String> expenseHeaders = [
        'Date',
        'Category',
        'Amount (${settings.currencySymbol})',
        'Notes',
      ];
      expenseSheet.appendRow(expenseHeaders.map((header) => TextCellValue(header)).toList());
      for (var i = 0; i < expenseHeaders.length; i++) {
        expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..cellStyle = headerStyle;
        expenseSheet.setColumnAutoFit(i); // Your correct syntax
      }
      
      final expenseData = await dbHelper.queryExpensesForVehicle(vehicleId);
      double expenseGrandTotal = 0.0;
      
      // --- THIS IS THE FIX: Track data rows ---
      List<int> expenseDataRowIndexes = [];
      for (var row in expenseData) {
        expenseDataRowIndexes.add(expenseSheet.maxRows); // Track this row
        expenseSheet.appendRow([
          TextCellValue(row[DatabaseHelper.columnServiceDate] ?? ''),
          TextCellValue(row[DatabaseHelper.columnCategory] ?? ''),
          TextCellValue((row[DatabaseHelper.columnTotalCost] ?? '').toString()),
          TextCellValue(row[DatabaseHelper.columnNotes] ?? 'N/A'),
        ]);
        
        double? expenseTotal = double.tryParse((row[DatabaseHelper.columnTotalCost] ?? '0').toString());
        if(expenseTotal != null) {
          expenseGrandTotal += expenseTotal;
        }
      }
      
      // Add Total Row for Expenses
      expenseSheet.appendRow([]); // Blank row
      expenseSheet.appendRow([
        null,
        TextCellValue('Total:'),
        TextCellValue('${settings.currencySymbol}${expenseGrandTotal.toStringAsFixed(2)}'),
        null
      ]);
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: expenseSheet.maxRows - 1))
        ..cellStyle = totalStyle;
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: expenseSheet.maxRows - 1))
        ..cellStyle = totalStyle;

      // --- THIS IS THE FIX ---
      // 8. Apply the dataStyle to all data cells in Expenses
      for (int r in expenseDataRowIndexes) {
        for (int c = 0; c < expenseHeaders.length; c++) {
          final cell = expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
          cell.cellStyle = dataStyle;
        }
      }
      // --- END OF FIX ---
      
      // 9. Delete the default blank sheet
      excel.delete('Sheet1');

      // 10. Save and Share (Unchanged)
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
      await Share.shareXFiles(
        [xfile],
        subject: '$vehicleName Service Report',
      );
      
      return 'Report generated!'; // Success message

    } catch (e) {
      print("Error creating Excel report: $e");
      return "An error occurred: $e";
    }
  }
}