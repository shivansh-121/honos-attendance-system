import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/guard.dart';
import '../models/attendance.dart';
import '../models/app_user.dart';
import '../models/advance.dart';

class PdfService {
  static Future<String?> generateAndPrintGuardReport({
    required Guard guard,
    required DateTime month,
    required List<Attendance> attendanceRecords,
    required Map<String, String> siteNames,
    required Map<String, String> supervisorNames,
    List<Advance> monthAdvances = const [],
    bool share = true,
  }) async {
    final pdf = pw.Document();

    // Sort attendance by date ascending safely
    attendanceRecords.sort((a, b) {
      final d1 = DateTime.tryParse(a.markedAt) ?? DateTime.tryParse(a.date) ?? DateTime.now();
      final d2 = DateTime.tryParse(b.markedAt) ?? DateTime.tryParse(b.date) ?? DateTime.now();
      return d1.compareTo(d2);
    });

    // Try to load the guard's face photo
    pw.MemoryImage? profileImage;
    if (guard.photo.length > 200) {
      try {
        final bytes = base64Decode(guard.photo);
        profileImage = pw.MemoryImage(bytes);
      } catch (e) {
        // Ignored
      }
    }

    final monthStr = DateFormat('MMMM yyyy').format(month);
    
    // Calculate total hours
    double totalHours = 0;
    for (var a in attendanceRecords) {
      if (a.checkOutTime.isNotEmpty) {
        try {
          final inParts = a.time.split(':');
          final outParts = a.checkOutTime.split(':');
          final inTime = DateTime(2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
          var outTime = DateTime(2000, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));
          if (outTime.isBefore(inTime)) outTime = outTime.add(const Duration(days: 1));
          totalHours += outTime.difference(inTime).inMinutes / 60.0;
        } catch (_) {}
      }
    }

    // Calculate Advances
    double totalAdvances = 0;
    for (var adv in monthAdvances) {
      totalAdvances += adv.amount;
    }
    double netPay = guard.salary - totalAdvances;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REPORT: ${guard.name.toUpperCase()}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1a237e'))),
                    pw.SizedBox(height: 6),
                    pw.Text('Monthly Attendance Record: $monthStr', style: pw.TextStyle(fontSize: 14, color: PdfColor.fromHex('#424242'), fontStyle: pw.FontStyle.italic)),
                  ],
                ),
                if (profileImage != null)
                  pw.Container(
                    width: 65,
                    height: 65,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColor.fromHex('#1a237e'), width: 2),
                      image: pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    width: 65,
                    height: 65,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle, 
                      color: PdfColor.fromHex('#e0e0e0'),
                      border: pw.Border.all(color: PdfColor.fromHex('#1a237e'), width: 2),
                    ),
                    child: pw.Center(child: pw.Text(guard.name.isNotEmpty ? guard.name[0].toUpperCase() : '?', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1a237e')))),
                  ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColor.fromHex('#b0bec5'), thickness: 1.5),
            pw.SizedBox(height: 20),

            // Guard Details Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f5f7fa'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: PdfColor.fromHex('#cfd8dc')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GUARD PROFILE DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1565c0'))),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Name', guard.name),
                            _buildDetailRow('Employee ID', guard.empId),
                            _buildDetailRow('Phone', guard.phone),
                            _buildDetailRow('DOB', guard.dob),
                            _buildDetailRow('Address', guard.address),
                            _buildDetailRow('Aadhaar No', guard.aadharNo),
                            _buildDetailRow('UAN No', guard.uanNo),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Status', guard.status.toUpperCase()),
                            _buildDetailRow('Join Date', guard.joinDate),
                            _buildDetailRow('Monthly Salary', guard.salary > 0 ? 'INR ${guard.salary.toStringAsFixed(0)}' : '--'),
                            _buildDetailRow('Bank Name', guard.bankName),
                            _buildDetailRow('Account No', guard.accountNo),
                            _buildDetailRow('IFSC Code', guard.ifsc),
                            _buildDetailRow('Total Advances', totalAdvances > 0 ? 'INR ${totalAdvances.toStringAsFixed(0)}' : '--'),
                            _buildDetailRow('Est. Net Pay', 'INR ${netPay.toStringAsFixed(0)}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),

            pw.Text('ATTENDANCE LOG', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1565c0'))),
            pw.SizedBox(height: 12),

            // Table
            _buildAttendanceTable(attendanceRecords, siteNames, supervisorNames),

            pw.SizedBox(height: 28),
            pw.Divider(color: PdfColor.fromHex('#b0bec5'), thickness: 1.5),
            pw.SizedBox(height: 12),

            // Footer / Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Report Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Row(
                  children: [
                    pw.Text('Total Working Hours: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${totalHours.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#d32f2f'))),
                  ]
                ),
              ],
            ),
          ];
        },
      ),
    );

    // Share / Print PDF
    final bytes = await pdf.save();
    final filename = '${guard.name.replaceAll(' ', '_')}_Report_${DateFormat('MMM_yyyy').format(month)}.pdf';
    
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return null;
    } else {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: filename,
          acceptedTypeGroups: [
            XTypeGroup(label: 'PDF', extensions: ['pdf']),
          ],
        );
        if (result == null) return null;
        final file = File(result.path);
        await file.writeAsBytes(bytes);
        return result.path;
      } else {
        final params = SaveFileDialogParams(data: bytes, fileName: filename);
        final filePath = await FlutterFileDialog.saveFile(params: params);
        return filePath;
      }
    }
  }

  static Future<String?> generateAndPrintSupervisorReport({
    required AppUser supervisor,
    required DateTime month,
    required List<Attendance> attendanceRecords,
    required Map<String, String> siteNames,
    required Map<String, String> supervisorNames,
    List<Advance> monthAdvances = const [],
    bool share = true,
  }) async {
    final pdf = pw.Document();

    // Sort attendance by date ascending safely
    attendanceRecords.sort((a, b) {
      final d1 = DateTime.tryParse(a.markedAt) ?? DateTime.tryParse(a.date) ?? DateTime.now();
      final d2 = DateTime.tryParse(b.markedAt) ?? DateTime.tryParse(b.date) ?? DateTime.now();
      return d1.compareTo(d2);
    });

    // Try to load the face photo
    pw.MemoryImage? profileImage;
    if (supervisor.photo.length > 200) {
      try {
        final bytes = base64Decode(supervisor.photo);
        profileImage = pw.MemoryImage(bytes);
      } catch (e) {
        // Ignored
      }
    }

    final monthStr = DateFormat('MMMM yyyy').format(month);
    final displayRole = supervisor.role.toUpperCase();
    
    // Calculate total hours
    double totalHours = 0;
    for (var a in attendanceRecords) {
      if (a.checkOutTime.isNotEmpty) {
        try {
          final inParts = a.time.split(':');
          final outParts = a.checkOutTime.split(':');
          final inTime = DateTime(2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
          var outTime = DateTime(2000, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));
          if (outTime.isBefore(inTime)) outTime = outTime.add(const Duration(days: 1));
          totalHours += outTime.difference(inTime).inMinutes / 60.0;
        } catch (_) {}
      }
    }

    // Calculate Advances
    double totalAdvances = 0;
    for (var adv in monthAdvances) {
      totalAdvances += adv.amount;
    }
    double netPay = supervisor.salary - totalAdvances;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REPORT: ${supervisor.name.toUpperCase()}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1a237e'))),
                    pw.SizedBox(height: 6),
                    pw.Text('Monthly Attendance Record: $monthStr', style: pw.TextStyle(fontSize: 14, color: PdfColor.fromHex('#424242'), fontStyle: pw.FontStyle.italic)),
                  ],
                ),
                if (profileImage != null)
                  pw.Container(
                    width: 65,
                    height: 65,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColor.fromHex('#1a237e'), width: 2),
                      image: pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    width: 65,
                    height: 65,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle, 
                      color: PdfColor.fromHex('#e0e0e0'),
                      border: pw.Border.all(color: PdfColor.fromHex('#1a237e'), width: 2),
                    ),
                    child: pw.Center(child: pw.Text(supervisor.name.isNotEmpty ? supervisor.name[0].toUpperCase() : '?', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1a237e')))),
                  ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColor.fromHex('#b0bec5'), thickness: 1.5),
            pw.SizedBox(height: 20),

            // Supervisor Details Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f5f7fa'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: PdfColor.fromHex('#cfd8dc')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('$displayRole PROFILE DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1565c0'))),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Employee ID', supervisor.empId),
                            _buildDetailRow('Name', supervisor.name),
                            _buildDetailRow('Username', supervisor.username),
                            _buildDetailRow('Phone', supervisor.phone),
                            _buildDetailRow('DOB', supervisor.dob),
                            _buildDetailRow('Address', supervisor.address),
                            _buildDetailRow('Aadhaar No', supervisor.aadharNo),
                            _buildDetailRow('UAN No', supervisor.uanNo),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Status', supervisor.status.toUpperCase()),
                            _buildDetailRow('Join Date', supervisor.joinDate.split('T').first),
                            _buildDetailRow('Monthly Salary', supervisor.salary > 0 ? 'INR ${supervisor.salary.toStringAsFixed(0)}' : '--'),
                            _buildDetailRow('Bank Name', supervisor.bankName),
                            _buildDetailRow('Account No', supervisor.accountNo),
                            _buildDetailRow('IFSC Code', supervisor.ifsc),
                            _buildDetailRow('Total Advances', totalAdvances > 0 ? 'INR ${totalAdvances.toStringAsFixed(0)}' : '--'),
                            _buildDetailRow('Est. Net Pay', 'INR ${netPay.toStringAsFixed(0)}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),
            
            pw.Text('ATTENDANCE LOG', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1565c0'))),
            pw.SizedBox(height: 12),

            // Table
            _buildAttendanceTable(
              attendanceRecords, 
              siteNames, 
              supervisorNames,
              showSupervisorColumn: supervisor.role.trim().toLowerCase() != 'executive' && supervisor.role.trim().toLowerCase() != 'employee' && supervisor.role.trim().toLowerCase() != 'office_employee',
            ),

            pw.SizedBox(height: 28),
            pw.Divider(color: PdfColor.fromHex('#b0bec5'), thickness: 1.5),
            pw.SizedBox(height: 12),

            // Footer / Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Report Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Row(
                  children: [
                    pw.Text('Total Working Hours: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${totalHours.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#d32f2f'))),
                  ]
                ),
              ],
            ),
          ];
        },
      ),
    );

    // Share / Print PDF
    final bytes = await pdf.save();
    final filename = '${supervisor.name.replaceAll(' ', '_')}_Report_${DateFormat('MMM_yyyy').format(month)}.pdf';
    
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return null;
    } else {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: filename,
          acceptedTypeGroups: [
            XTypeGroup(label: 'PDF', extensions: ['pdf']),
          ],
        );
        if (result == null) return null;
        final file = File(result.path);
        await file.writeAsBytes(bytes);
        return result.path;
      } else {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = Directory('/storage/emulated/0/Downloads');
          }
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          directory = await getDownloadsDirectory();
        }
        if (directory == null) directory = await getApplicationDocumentsDirectory();
        
        final savePath = '${directory.path}/$filename';
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        return savePath;
      }
    }
  }

  static pw.Widget _buildAttendanceTable(List<Attendance> records, Map<String, String> siteNames, Map<String, String> supervisorNames, {bool showSupervisorColumn = true}) {
    if (records.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(24),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#cfd8dc')),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          color: PdfColor.fromHex('#fafafa')
        ),
        child: pw.Center(child: pw.Text('No shifts recorded for this month.', style: pw.TextStyle(color: PdfColor.fromHex('#757575'), fontStyle: pw.FontStyle.italic))),
      );
    }

    final headers = ['Date', 'Site'];
    if (showSupervisorColumn) headers.add('Supervisor');
    headers.addAll(['Check In', 'Check Out', 'Status', 'Hours']);

    final data = records.map((a) {
      final date = DateTime.tryParse(a.markedAt) ?? DateTime.tryParse(a.date) ?? DateTime.now();
      
      String displaySite = siteNames[a.siteId] ?? '';
      if (displaySite.isEmpty) {
        if (a.siteId == 'admin_manual') {
          displaySite = 'Manual Entry';
        } else if (a.siteId.toLowerCase().contains('main') || a.siteId.toLowerCase().contains('office')) {
          displaySite = 'Main Office';
        } else if (a.siteId.length < 20) {
          displaySite = a.siteId; // Could be a custom short name
        } else {
          displaySite = 'Unknown/Deleted Site';
        }
      }

      final supervisor = supervisorNames[a.supervisorId] ?? 'Unknown';
      final checkIn = a.time.isNotEmpty ? a.time : '--';
      
      String checkOut = '--';
      double hoursValue = 0;

      if (a.checkOutTime.isNotEmpty) {
        try {
          final inParts = a.time.split(':');
          final outParts = a.checkOutTime.split(':');
          final inTime = DateTime(2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
          var outTime = DateTime(2000, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));
          if (outTime.isBefore(inTime)) outTime = outTime.add(const Duration(days: 1));
          
          checkOut = a.checkOutTime;
          hoursValue = outTime.difference(inTime).inMinutes / 60.0;
        } catch (_) {
          checkOut = a.checkOutTime; // Fallback
        }
      }

      final hoursStr = hoursValue > 0 ? '${hoursValue.toStringAsFixed(1)} h' : '--';

      final row = [
        DateFormat('dd MMM yyyy').format(date),
        displaySite,
      ];
      if (showSupervisorColumn) row.add(supervisor);
      row.addAll([
        checkIn,
        checkOut,
        a.status.toUpperCase(),
        hoursStr,
      ]);

      return row;
    }).toList();

    Map<int, pw.Alignment> alignments = {};
    int index = 0;
    alignments[index++] = pw.Alignment.centerLeft; // Date
    alignments[index++] = pw.Alignment.centerLeft; // Site
    if (showSupervisorColumn) alignments[index++] = pw.Alignment.centerLeft; // Supervisor
    alignments[index++] = pw.Alignment.center; // Check In
    alignments[index++] = pw.Alignment.center; // Check Out
    alignments[index++] = pw.Alignment.center; // Status
    alignments[index++] = pw.Alignment.center; // Hours

    Map<int, pw.TableColumnWidth> colWidths = {};
    int cIndex = 0;
    colWidths[cIndex++] = const pw.FlexColumnWidth(2.5); // Date
    colWidths[cIndex++] = const pw.FlexColumnWidth(3.0); // Site
    if (showSupervisorColumn) colWidths[cIndex++] = const pw.FlexColumnWidth(2.5); // Supervisor
    colWidths[cIndex++] = const pw.FlexColumnWidth(2.0); // Check In
    colWidths[cIndex++] = const pw.FlexColumnWidth(2.0); // Check Out
    colWidths[cIndex++] = const pw.FlexColumnWidth(2.5); // Status
    colWidths[cIndex++] = const pw.FlexColumnWidth(2.0); // Hours

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColor.fromHex('#cfd8dc'), width: 1),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1976d2')),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#f1f8ff')),
      cellStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
      cellHeight: 28,
      cellAlignments: alignments,
      columnWidths: colWidths,
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 85,
            child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#546e7a'))),
          ),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? '--' : value, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#212121'))),
          ),
        ],
      ),
    );
  }
}
