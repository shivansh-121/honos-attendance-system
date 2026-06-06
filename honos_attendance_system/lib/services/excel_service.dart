import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/guard.dart';

class ExcelService {
  static Future<void> exportCentralLedger({
    required DateTime month,
    required List<Guard> allGuards,
    required List<AppUser> allUsers,
    required bool includeGuards,
    required bool includeSupervisors,
    required bool includeExecutives,
    required bool includeEmployees,
  }) async {
    final db = FirebaseFirestore.instance;

    final attendanceSnap = await db.collection('attendance').get();
    final allRecords = attendanceSnap.docs.map((d) => d.data()).toList();
    
    final advancesSnap = await db.collection('advances').get();
    final allAdvances = advancesSnap.docs.map((d) => d.data()).toList();

    final monthAtt = allRecords.where((a) {
      final dateStr = a['markedAt'] as String? ?? '';
      try {
        final d = DateTime.parse(dateStr);
        return d.year == month.year && d.month == month.month;
      } catch (_) {
        return false;
      }
    }).toList();

    final monthAdv = allAdvances.where((a) {
      final dateStr = a['date'] as String? ?? '';
      try {
        final d = DateTime.parse(dateStr);
        return d.year == month.year && d.month == month.month;
      } catch (_) {
        return false;
      }
    }).toList();

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Central Ledger');
    final sheet = excel['Central Ledger'];
    excel.setDefaultSheet('Central Ledger');

    final monthStr = DateFormat('MMM yyyy').format(month);
    
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    final normalStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("Q1"));
    var titleCell = sheet.cell(CellIndex.indexByString("A1"));
    titleCell.value = TextCellValue("Honos Protection Services Pvt. Ltd.");
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16, horizontalAlign: HorizontalAlign.Center);

    sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("C2"));
    var siteCell = sheet.cell(CellIndex.indexByString("A2"));
    siteCell.value = TextCellValue("Name of Point :- Central Ledger");
    siteCell.cellStyle = CellStyle(bold: true);

    var monthCell = sheet.cell(CellIndex.indexByString("Q2"));
    monthCell.value = TextCellValue("Month :- ${DateFormat('MMM-yy').format(month)}");
    monthCell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right);

    final headers = [
      'Sr. No.', 'Name', 'Rank', 'Fix Salary', 'O.T. Salary', 'Attn.', 'O.T. Attn.', 'Total Attn.', 
      'Salary Amt.', 'O.T. Amt.', 'Total Amt.', 'Adv.', 'Oth. Ded.', 'Total Ded.', 'Net Salry', 'Bank Details', 'Signature'
    ];

    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    sheet.setColumnWidth(0, 8);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 12);
    sheet.setColumnWidth(8, 15);
    sheet.setColumnWidth(9, 15);
    sheet.setColumnWidth(10, 15);
    sheet.setColumnWidth(11, 12);
    sheet.setColumnWidth(12, 12);
    sheet.setColumnWidth(13, 12);
    sheet.setColumnWidth(14, 15);
    sheet.setColumnWidth(15, 50);
    sheet.setColumnWidth(16, 15);

    int currentRow = 4;
    int srNo = 1;

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    final List<dynamic> includedPeople = [];
    if (includeGuards) includedPeople.addAll(allGuards);
    if (includeSupervisors) includedPeople.addAll(allUsers.where((u) => u.role == 'supervisor'));
    if (includeExecutives) includedPeople.addAll(allUsers.where((u) => u.role == 'executive'));
    if (includeEmployees) includedPeople.addAll(allUsers.where((u) => u.role == 'employee'));

    for (var person in includedPeople) {
      final isGuard = person is Guard;
      final id = isGuard ? person.id : (person as AppUser).id;
      final name = isGuard ? person.name : (person as AppUser).name;
      final role = isGuard ? 'Guard' : (person as AppUser).role.toUpperCase();
      final salaryStr = isGuard ? person.salary : (person as AppUser).salary;
      final salary = double.tryParse(salaryStr.toString()) ?? 0.0;
      final bankDetails = isGuard ? 'A/c: ${person.accountNo} | IFSC: ${person.ifsc}' : '';

      final myAtt = monthAtt.where((a) {
        if (isGuard) return a['guardId'] == id;
        return a['supervisorId'] == id || a['guardId'] == id; 
      }).toList();

      final myUniqueDates = myAtt.map((a) => a['date']).toSet();
      final daysWorked = myUniqueDates.length;

      final earnedSalary = (salary / daysInMonth) * daysWorked;

      final myAdv = monthAdv.where((a) => a['userId'] == id).toList();
      final totalAdvances = myAdv.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));

      final netPayable = earnedSalary - totalAdvances;

      final rowData = [
        IntCellValue(srNo),
        TextCellValue(name),
        TextCellValue(role),
        DoubleCellValue(salary),
        const IntCellValue(0), // O.T. Salary
        IntCellValue(daysWorked),
        const IntCellValue(0), // O.T. Attn
        IntCellValue(daysWorked), // Total Attn
        DoubleCellValue(double.parse(earnedSalary.toStringAsFixed(2))),
        const IntCellValue(0), // O.T. Amt
        DoubleCellValue(double.parse(earnedSalary.toStringAsFixed(2))), // Total Amt
        DoubleCellValue(totalAdvances),
        const IntCellValue(0), // Oth. Ded.
        DoubleCellValue(totalAdvances), // Total Ded.
        DoubleCellValue(double.parse(netPayable.toStringAsFixed(2))),
        TextCellValue(bankDetails),
        TextCellValue(''), // Signature
      ];

      for (int col = 0; col < rowData.length; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        cell.value = rowData[col];
        cell.cellStyle = normalStyle;
      }

      srNo++;
      currentRow++;
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception("Failed to encode Excel file");

    final dir = await getTemporaryDirectory();
    final currentDate = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final fileName = 'Central_Ledger_$currentDate.xlsx';
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Monthly Payroll Ledger ($monthStr)',
    );
  }
}
