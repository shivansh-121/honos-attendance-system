import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../models/site.dart';
import '../models/app_user.dart';

class ExcelService {
  static Future<void> exportSiteAttendance(Site site, DateTime month) async {
    final db = FirebaseFirestore.instance;

    // 1. Fetch all attendance records for this site
    final attendanceSnap = await db
        .collection('attendance')
        .where('siteId', isEqualTo: site.id)
        .get();

    final allRecords = attendanceSnap.docs.map((d) => d.data()).toList();
    
    // Filter records for the specified month
    final records = allRecords.where((r) {
      final dateStr = r['markedAt'] as String;
      try {
        final d = DateTime.parse(dateStr);
        return d.year == month.year && d.month == month.month;
      } catch (_) {
        return false;
      }
    }).toList();

    // Group attendance by guardId to count distinct days
    final Map<String, Set<String>> guardAttendanceDays = {};
    for (var r in records) {
      final gId = r['guardId'] as String;
      final dateStr = r['markedAt'] as String;
      try {
        final d = DateTime.parse(dateStr);
        final dayStr = '${d.year}-${d.month}-${d.day}';
        guardAttendanceDays.putIfAbsent(gId, () => {}).add(dayStr);
      } catch (_) {}
    }

    // 2. Fetch guards
    final guardIds = guardAttendanceDays.keys.toSet();
    final Map<String, Map<String, dynamic>> guardsMap = {};
    for (var gId in guardIds) {
      final gSnap = await db.collection('guards').doc(gId).get();
      if (gSnap.exists) {
        guardsMap[gId] = gSnap.data()!;
      }
    }

    // 3. Fetch advances for the month for these guards
    final advancesSnap = await db.collection('advances').get();
    final advances = advancesSnap.docs.map((d) => d.data()).toList();
    
    final Map<String, double> guardAdvances = {};
    for (var adv in advances) {
      final uId = adv['userId'] as String;
      if (guardIds.contains(uId)) {
        final dateStr = adv['date'] as String;
        try {
          final d = DateTime.parse(dateStr);
          if (d.year == month.year && d.month == month.month) {
             final amt = (adv['amount'] as num).toDouble();
             guardAdvances[uId] = (guardAdvances[uId] ?? 0.0) + amt;
          }
        } catch (_) {}
      }
    }

    // 4. Create Excel document
    var excel = Excel.createExcel();
    Sheet sheet = excel['Attendance'];
    excel.setDefaultSheet('Attendance');

    // Title and Headers Formatting
    CellStyle titleStyle = CellStyle(
      bold: true,
      fontSize: 26,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle headerStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle normalStyle = CellStyle(
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Row 1 & 2: Company Title
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("R2"));
    var cellA1 = sheet.cell(CellIndex.indexByString("A1"));
    cellA1.value = TextCellValue("Honos Protection Services Pvt. Ltd.");
    cellA1.cellStyle = titleStyle;

    // Apply borders to all cells in the merged title area
    for (int r = 0; r <= 1; r++) {
      for (int c = 0; c <= 17; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = titleStyle;
      }
    }

    // Row 3: Point Name and Month
    final monthStr = DateFormat('MMM-yy').format(month);
    sheet.merge(CellIndex.indexByString("A3"), CellIndex.indexByString("E3"));
    var cellA3 = sheet.cell(CellIndex.indexByString("A3"));
    cellA3.value = TextCellValue("Name of Point :- ${site.name}");
    cellA3.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Left, fontSize: 13);

    sheet.merge(CellIndex.indexByString("M3"), CellIndex.indexByString("R3"));
    var cellM3 = sheet.cell(CellIndex.indexByString("M3"));
    cellM3.value = TextCellValue("Month :- $monthStr");
    cellM3.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right, fontSize: 13);

    sheet.appendRow([]); // empty row 4 for spacing, or just skip

    // Row 5: Column Headers
    List<String> headers = [
      'Sr. No.', 'Name', 'Rank', 'UAN No.', 'Fix Salary', 'O.T. Salary', 
      'Attn.', 'O.T. Attn.', 'Total Attn.', 'Salary Amt.', 'O.T. Amt.', 
      'Total Amt.', 'Adv.', 'Oth. Ded.', 'Total Ded.', 'Net Salry', 
      'Bank Details', 'Signature'
    ];
    
    // Manually set row 5 (index 4)
    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Set column widths roughly
    sheet.setColumnWidth(0, 8.0); // Sr. No.
    sheet.setColumnWidth(1, 25.0); // Name
    sheet.setColumnWidth(2, 12.0); // Rank
    sheet.setColumnWidth(3, 15.0); // UAN No.
    for (int i = 4; i <= 15; i++) {
      sheet.setColumnWidth(i, 14.0); // Amounts and Attn
    }
    sheet.setColumnWidth(16, 35.0); // Bank Details
    sheet.setColumnWidth(17, 20.0); // Signature

    // 5. Add Data Rows
    int srNo = 1;
    int currentRow = 5; // Start from row 6

    // Sort guards by name
    final sortedGuardIds = guardIds.toList()..sort((a, b) {
      final nameA = guardsMap[a]?['name'] ?? '';
      final nameB = guardsMap[b]?['name'] ?? '';
      return nameA.compareTo(nameB);
    });

    for (var gId in sortedGuardIds) {
      final guard = guardsMap[gId];
      final guardName = guard?['name'] ?? 'Unknown';
      
      final fixSalary = (guard?['salary'] ?? 0).toDouble();
      final otSalary = 0.0; // Default to 0 based on plan
      
      final attnDays = guardAttendanceDays[gId]?.length ?? 0;
      final otAttn = 0; // Default to 0
      final totalAttn = attnDays + otAttn;

      // Salary calculation: (Fix Salary / 30) * Attn
      final double salaryAmtDouble = (fixSalary / 30) * attnDays;
      final int salaryAmt = salaryAmtDouble.round();

      final otAmt = 0;
      final int totalAmt = salaryAmt + otAmt;

      final adv = guardAdvances[gId] ?? 0.0;
      final int advInt = adv.round();
      final int othDed = 0;
      final int totalDed = advInt + othDed;

      final int netSalary = totalAmt - totalDed;
      
      // Bank Details
      String bankDetails = '';
      final bName = guard?['bankName']?.toString().trim() ?? '';
      final aNo = guard?['accountNo']?.toString().trim() ?? '';
      final ifsc = guard?['ifsc']?.toString().trim() ?? '';
      
      List<String> bankParts = [];
      if (bName.isNotEmpty) bankParts.add(bName);
      if (aNo.isNotEmpty) bankParts.add('A/c: $aNo');
      if (ifsc.isNotEmpty) bankParts.add('IFSC: $ifsc');
      
      bankDetails = bankParts.join(' | ');

      final uanNo = guard?['uanNo']?.toString().trim() ?? '';

      final rowData = [
        TextCellValue(srNo.toString()),
        TextCellValue(guardName),
        TextCellValue("Guard"), // Rank
        TextCellValue(uanNo), // UAN No.
        DoubleCellValue(fixSalary),
        DoubleCellValue(otSalary),
        DoubleCellValue(attnDays.toDouble()),
        DoubleCellValue(otAttn.toDouble()),
        DoubleCellValue(totalAttn.toDouble()),
        DoubleCellValue(salaryAmt.toDouble()),
        DoubleCellValue(otAmt.toDouble()),
        DoubleCellValue(totalAmt.toDouble()),
        DoubleCellValue(advInt.toDouble()),
        DoubleCellValue(othDed.toDouble()),
        DoubleCellValue(totalDed.toDouble()),
        DoubleCellValue(netSalary.toDouble()),
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

    // 6. Save to temporary directory
    final bytes = excel.encode();
    if (bytes == null) throw Exception("Failed to encode Excel file");

    final dir = await getTemporaryDirectory();
    final fileName = '${site.name.replaceAll(' ', '_')}_Attendance_$monthStr.xlsx';
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);

    // 7. Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Monthly Payroll & Attendance for ${site.name} ($monthStr)',
    );
  }

  static Future<void> exportMonthlyPayroll(DateTime month, List<dynamic> guards, List<dynamic> users, List<dynamic> advances) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Payroll'];
    excel.setDefaultSheet('Payroll');

    List<String> headers = [
      'Name',
      'Role',
      'Employee ID',
      'Fixed Salary (INR)',
      'Advances Taken (INR)',
      'Net Pay (INR)'
    ];
    sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final monthAdvances = advances.where((a) {
      final d = DateTime.tryParse(a.date);
      return d != null && d.year == month.year && d.month == month.month;
    }).toList();

    // Process Guards
    for (var g in guards) {
      final userAdvances = monthAdvances.where((a) => a.userId == g.id && a.userType == 'guard').toList();
      final totalAdvance = userAdvances.fold<double>(0, (sum, a) => sum + a.amount);
      final netPay = g.salary - totalAdvance;

      sheetObject.appendRow([
        TextCellValue(g.name),
        TextCellValue('Guard'),
        TextCellValue(g.empId),
        DoubleCellValue(g.salary),
        DoubleCellValue(totalAdvance),
        DoubleCellValue(netPay),
      ]);
    }

    // Process Supervisors
    final sups = users.where((u) => u.role == 'supervisor').toList();
    for (var s in sups) {
      final userAdvances = monthAdvances.where((a) => a.userId == s.id && a.userType == 'supervisor').toList();
      final totalAdvance = userAdvances.fold<double>(0, (sum, a) => sum + a.amount);
      final netPay = s.salary - totalAdvance;

      sheetObject.appendRow([
        TextCellValue(s.name),
        TextCellValue('Supervisor'),
        TextCellValue('N/A'),
        DoubleCellValue(s.salary),
        DoubleCellValue(totalAdvance),
        DoubleCellValue(netPay),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception("Failed to encode Excel file");

    final dir = await getTemporaryDirectory();
    final monthStr = DateFormat('MMM_yyyy').format(month);
    final fileName = 'Payroll_Report_$monthStr.xlsx';
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Payroll Report for $monthStr',
    );
  }

  static Future<void> exportAllSupervisors(List<AppUser> supervisors, List<Site> sites) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Supervisors Details'];
    excel.setDefaultSheet('Supervisors Details');

    List<String> headers = [
      'Name',
      'Username',
      'Phone',
      'DOB',
      'Aadhaar No.',
      'UAN No.',
      'Bank Name',
      'Account No.',
      'IFSC Code',
      'Fixed Salary (INR)',
      'Assigned Site',
      'Join Date',
      'Status'
    ];
    
    // Add Headers
    for (int col = 0; col < headers.length; col++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1B3B60'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Set Column Widths
    for (int i = 0; i < headers.length; i++) {
      sheetObject.setColumnWidth(i, 20.0);
    }

    // Process Supervisors
    for (int i = 0; i < supervisors.length; i++) {
      final s = supervisors[i];
      final siteName = sites.firstWhere(
        (site) => site.id == s.siteId,
        orElse: () => const Site(id: '', name: 'Not Assigned', address: '', lat: 0, lng: 0, radius: 0)
      ).name;

      final rowData = [
        TextCellValue(s.name),
        TextCellValue(s.username),
        TextCellValue(s.phone),
        TextCellValue(s.dob),
        TextCellValue(s.aadharNo),
        TextCellValue(s.uanNo),
        TextCellValue(s.bankName),
        TextCellValue(s.accountNo),
        TextCellValue(s.ifsc),
        DoubleCellValue(s.salary),
        TextCellValue(siteName),
        TextCellValue(s.joinDate.split('T').first),
        TextCellValue(s.status),
      ];

      for (int col = 0; col < rowData.length; col++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1));
        cell.value = rowData[col];
        cell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception("Failed to encode Excel file");

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final fileName = 'All_Supervisors_Report_$dateStr.xlsx';
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'All Supervisors Details Report - $dateStr',
    );
  }
}
