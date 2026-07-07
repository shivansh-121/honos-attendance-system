import 'dart:io';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

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
    String? siteId,
    bool share = false,
  }) async {
    final db = FirebaseFirestore.instance;

    // Normalise to midnight so comparisons are date-only
    final rangeStart = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final rangeEnd   = DateTime(toDate.year,   toDate.month,   toDate.day, 23, 59, 59);

    // Fetch attendance – filter by siteId at the Firestore level when possible
    Query attendanceQuery = db.collection('attendance');
    if (siteId != null) {
      attendanceQuery = attendanceQuery.where('siteId', isEqualTo: siteId);
    }
    final attendanceSnap = await attendanceQuery.get();
    final allRecords = attendanceSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    final advancesSnap = await db.collection('advances').get();
    final allAdvances = advancesSnap.docs.map((d) => d.data()).toList();

    final bytes = await Isolate.run(() {
      // Filter attendance within selected date range (inclusive)
      final monthAtt = allRecords.where((a) {
        final dateStr = (a['markedAt'] as String?)?.isNotEmpty == true
            ? a['markedAt'] as String
            : a['date'] as String? ?? '';
        final matchesSite = siteId == null || a['siteId'] == siteId;
        try {
          final d = DateTime.parse(dateStr);
          return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd) && matchesSite;
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

      final daysInRange = toDate.difference(fromDate).inDays + 1;

      // When a specific site is selected, restrict the people list to that site only.
      // Guards have a direct siteId field; AppUsers (supervisors/executives/employees)
      // also have a siteId field. If siteId is null (All Sites), include everyone.
      final List<dynamic> includedPeople = [];
      if (includeGuards) {
        includedPeople.addAll(
          siteId == null
              ? allGuards
              : allGuards.where((g) => g.siteId == siteId),
        );
      }
      if (includeSupervisors) {
        includedPeople.addAll(
          allUsers.where((u) =>
              u.role == 'supervisor' &&
              (siteId == null || u.siteId == siteId)),
        );
      }
      if (includeExecutives) {
        includedPeople.addAll(
          allUsers.where((u) =>
              u.role == 'executive' &&
              (siteId == null || u.siteId == siteId)),
        );
      }
      if (includeEmployees) {
        includedPeople.addAll(
          allUsers.where((u) =>
              (u.role == 'employee' || u.role == 'office_employee') &&
              (siteId == null || u.siteId == siteId)),
        );
      }

      for (var person in includedPeople) {
        final isGuard = person is Guard;
        final id = isGuard ? person.id : (person as AppUser).id;
        final name = isGuard ? person.name : (person as AppUser).name;
        final role = isGuard ? 'Guard' : (person as AppUser).role.toUpperCase();
        final salaryStr = isGuard ? person.salary : (person as AppUser).salary;
        final salary = double.tryParse(salaryStr.toString()) ?? 0.0;
        final appUser = isGuard ? null : (person as AppUser);
        final bankDetails = isGuard
            ? 'A/c: ${person.accountNo} | IFSC: ${person.ifsc}'
            : 'A/c: ${appUser!.accountNo} | IFSC: ${appUser.ifsc}';

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
          const IntCellValue(0),
          IntCellValue(daysWorked),
          const IntCellValue(0),
          IntCellValue(daysWorked),
          DoubleCellValue(double.parse(earnedSalary.toStringAsFixed(2))),
          const IntCellValue(0),
          DoubleCellValue(double.parse(earnedSalary.toStringAsFixed(2))),
          DoubleCellValue(advAmt),
          DoubleCellValue(uniAmt),
          DoubleCellValue(messAmt),
          DoubleCellValue(othAmt),
          DoubleCellValue(totalAdvances),
          DoubleCellValue(double.parse(netPayable.toStringAsFixed(2))),
          TextCellValue(bankDetails),
          TextCellValue(''),
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

    // ── Save / Share the generated bytes ──────────────────────────────────────
    final fileRangeStr = '${DateFormat('dd_MMM_yyyy').format(fromDate)}_to_${DateFormat('dd_MMM_yyyy').format(toDate)}';
    final fileName = 'Central_Ledger_$fileRangeStr.xlsx';

    if (share) {
      // Mobile: share via system share sheet
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Central Ledger – $fileRangeStr',
        ),
      );
    } else {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop: show native Save-As dialog
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Excel', extensions: ['xlsx']),
          ],
        );
        if (result == null) return; // user cancelled
        final file = File(result.path);
        await file.writeAsBytes(bytes);
      } else if (Platform.isAndroid) {
        // Android: write to temp then show save dialog
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(sourceFilePath: file.path),
        );
      } else {
        // iOS / fallback: save to documents directory
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
      }
    }
  }
}
