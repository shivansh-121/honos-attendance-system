import 'dart:io';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/guard.dart';

class ExcelService {
  static Future<void> exportCentralLedger({
    required DateTime fromDate,
    required DateTime toDate,
    required List<Guard> allGuards,
    required List<AppUser> allUsers,
    required bool includeGuards,
    required bool includeSupervisors,
    required bool includeExecutives,
    required bool includeEmployees,
  }) async {
    final db = FirebaseFirestore.instance;

    // Normalise to midnight so comparisons are date-only
    final rangeStart = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final rangeEnd   = DateTime(toDate.year,   toDate.month,   toDate.day, 23, 59, 59);

    final attendanceSnap = await db.collection('attendance').get();
    final allRecords = attendanceSnap.docs.map((d) => d.data()).toList();
    
    final advancesSnap = await db.collection('advances').get();
    final allAdvances = advancesSnap.docs.map((d) => d.data()).toList();

    final bytes = await Isolate.run(() {
      // Filter attendance within selected date range (inclusive)
      final monthAtt = allRecords.where((a) {
        final dateStr = (a['markedAt'] as String?)?.isNotEmpty == true
            ? a['markedAt'] as String
            : a['date'] as String? ?? '';
        try {
          final d = DateTime.parse(dateStr);
          return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);
        } catch (_) {
          return false;
        }
      }).toList();

      // Filter advances within selected date range (inclusive)
      final monthAdv = allAdvances.where((a) {
        final dateStr = a['date'] as String? ?? '';
        try {
          final d = DateTime.parse(dateStr);
          return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);
        } catch (_) {
          return false;
        }
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Central Ledger'];
      excel.delete('Sheet1');

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      final normalStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

      sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("S1"));
      var titleCell = sheet.cell(CellIndex.indexByString("A1"));
      titleCell.value = TextCellValue("Honos Protection Services Pvt. Ltd.");
      titleCell.cellStyle = CellStyle(bold: true, fontSize: 16, horizontalAlign: HorizontalAlign.Center);

      final rangeLabelShort = '${DateFormat('dd MMM yy').format(fromDate)} – ${DateFormat('dd MMM yy').format(toDate)}';

      sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("C2"));
      var siteCell = sheet.cell(CellIndex.indexByString("A2"));
      siteCell.value = TextCellValue("Name of Point :- Central Ledger");
      siteCell.cellStyle = CellStyle(bold: true);

      var monthCell = sheet.cell(CellIndex.indexByString("S2"));
      monthCell.value = TextCellValue("Period :- $rangeLabelShort");
      monthCell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right);

      final headers = [
        'Sr. No.', 'Name', 'Rank', 'Fix Salary', 'O.T. Salary', 'Attn.', 'O.T. Attn.', 'Total Attn.', 
        'Salary Amt.', 'O.T. Amt.', 'Total Amt.', 'Adv.', 'Uniform', 'Mess', 'Oth. Ded.', 'Total Ded.', 'Net Salry', 'Bank Details', 'Signature'
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
      sheet.setColumnWidth(14, 12);
      sheet.setColumnWidth(15, 12);
      sheet.setColumnWidth(16, 15);
      sheet.setColumnWidth(17, 50);
      sheet.setColumnWidth(18, 15);

      int currentRow = 4;
      int srNo = 1;

      // Total days in the selected range (used as denominator for pro-rata salary)
      final daysInRange = toDate.difference(fromDate).inDays + 1;

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

        final earnedSalary = daysInRange > 0 ? (salary / daysInRange) * daysWorked : 0.0;

        final myAdv = monthAdv.where((a) => a['userId'] == id).toList();
        double advAmt = 0;
        double uniAmt = 0;
        double messAmt = 0;
        double othAmt = 0;

        for (var a in myAdv) {
          final amt = double.tryParse(a['amount'].toString()) ?? 0.0;
          final type = a['type']?.toString() ?? 'advance';
          if (type == 'uniform') {
            uniAmt += amt;
          } else if (type == 'mess') {
            messAmt += amt;
          } else if (type == 'other') {
            othAmt += amt;
          } else {
            advAmt += amt;
          }
        }
        final totalAdvances = advAmt + uniAmt + messAmt + othAmt;

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
          DoubleCellValue(advAmt), // Adv.
          DoubleCellValue(uniAmt), // Uniform
          DoubleCellValue(messAmt), // Mess
          DoubleCellValue(othAmt), // Oth. Ded.
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

      final b = excel.encode();
      if (b == null) throw Exception("Failed to encode Excel file");
      return b;
    });

    final fromStr = DateFormat('dd_MMM_yyyy').format(fromDate);
    final toStr   = DateFormat('dd_MMM_yyyy').format(toDate);
    final rangeLabel = '${DateFormat('dd MMM yyyy').format(fromDate)} – ${DateFormat('dd MMM yyyy').format(toDate)}';
    final dir = await getTemporaryDirectory();
    final fileName = 'Central_Ledger_${fromStr}_to_$toStr.xlsx';
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Payroll Ledger ($rangeLabel)',
      ),
    );
  }
}
