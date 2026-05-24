import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/guard.dart';
import '../models/attendance.dart';
import '../models/app_user.dart';

class PdfService {
  static Future<void> generateAndPrintGuardReport({
    required Guard guard,
    required DateTime month,
    required List<Attendance> attendanceRecords,
    required Map<String, String> siteNames,
    required Map<String, String> supervisorNames,
  }) async {
    final pdf = pw.Document();

    // Sort attendance by date ascending
    attendanceRecords.sort((a, b) => a.markedAt.compareTo(b.markedAt));

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
                    pw.Text('Guard Shift Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('Month: $monthStr', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                if (profileImage != null)
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      image: pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey300),
                    child: pw.Center(child: pw.Text(guard.name.isNotEmpty ? guard.name[0] : '?', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                  ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Guard Details Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Guard Profile Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Name', guard.name),
                            _buildDetailRow('Emp ID', guard.empId),
                            _buildDetailRow('Phone', guard.phone),
                            _buildDetailRow('DOB', guard.dob),
                            _buildDetailRow('Address', guard.address),
                            _buildDetailRow('Aadhaar No', guard.aadharNo),
                            _buildDetailRow('UAN No', guard.uanNo),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Status', guard.status.toUpperCase()),
                            _buildDetailRow('Join Date', guard.joinDate),
                            _buildDetailRow('Salary', guard.salary > 0 ? 'INR ${guard.salary.toStringAsFixed(0)}' : '--'),
                            _buildDetailRow('Bank Name', guard.bankName),
                            _buildDetailRow('Account No', guard.accountNo),
                            _buildDetailRow('IFSC', guard.ifsc),
                            _buildDetailRow('Branch', guard.branch),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Table
            _buildAttendanceTable(attendanceRecords, siteNames, supervisorNames),

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Footer / Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Working Hours: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('${totalHours.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ],
            ),
          ];
        },
      ),
    );

    // Share / Print PDF
    final bytes = await pdf.save();
    final filename = '${guard.name.replaceAll(' ', '_')}_Report_${DateFormat('MMM_yyyy').format(month)}.pdf';
    
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static Future<void> generateAndPrintSupervisorReport({
    required AppUser supervisor,
    required DateTime month,
    required List<Attendance> attendanceRecords,
    required Map<String, String> siteNames,
    required Map<String, String> supervisorNames,
  }) async {
    final pdf = pw.Document();

    // Sort attendance by date ascending
    attendanceRecords.sort((a, b) => a.markedAt.compareTo(b.markedAt));

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
                    pw.Text('Supervisor Shift Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('Month: $monthStr', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                if (profileImage != null)
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      image: pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey300),
                    child: pw.Center(child: pw.Text(supervisor.name.isNotEmpty ? supervisor.name[0] : '?', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                  ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Supervisor Details Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Supervisor Profile Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
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
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Status', supervisor.status.toUpperCase()),
                            _buildDetailRow('Join Date', supervisor.joinDate.split('T').first),
                            _buildDetailRow('Salary', supervisor.salary > 0 ? 'INR ${supervisor.salary.toStringAsFixed(0)}' : '--'),
                            _buildDetailRow('Bank Name', supervisor.bankName),
                            _buildDetailRow('Account No', supervisor.accountNo),
                            _buildDetailRow('IFSC', supervisor.ifsc),
                            _buildDetailRow('Branch', supervisor.branch),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Table
            _buildAttendanceTable(attendanceRecords, siteNames, supervisorNames),

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Footer / Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Working Hours: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('${totalHours.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ],
            ),
          ];
        },
      ),
    );

    // Share / Print PDF
    final bytes = await pdf.save();
    final filename = '${supervisor.name.replaceAll(' ', '_')}_Report_${DateFormat('MMM_yyyy').format(month)}.pdf';
    
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static pw.Widget _buildAttendanceTable(List<Attendance> records, Map<String, String> siteNames, Map<String, String> supervisorNames) {
    if (records.isEmpty) {
      return pw.Center(child: pw.Text('No shifts recorded for this month.', style: const pw.TextStyle(color: PdfColors.grey600)));
    }

    final headers = ['Date', 'Site', 'Supervisor', 'Check In', 'Check Out', 'Hours'];

    final data = records.map((a) {
      final date = DateTime.parse(a.markedAt);
      final site = siteNames[a.siteId] ?? 'Unknown Site';
      final supervisor = supervisorNames[a.supervisorId] ?? 'Unknown Supervisor';
      final checkIn = DateFormat('hh:mm a').format(date);
      
      String checkOut = '--';
      double hoursValue = 0;

      if (a.checkOutTime.isNotEmpty) {
        try {
          final inParts = a.time.split(':');
          final outParts = a.checkOutTime.split(':');
          final inTime = DateTime(2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
          var outTime = DateTime(2000, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));
          if (outTime.isBefore(inTime)) outTime = outTime.add(const Duration(days: 1));
          
          checkOut = DateFormat('hh:mm a').format(outTime);
          hoursValue = outTime.difference(inTime).inMinutes / 60.0;
        } catch (_) {
          checkOut = a.checkOutTime; // Fallback
        }
      }

      final hoursStr = hoursValue > 0 ? '${hoursValue.toStringAsFixed(1)} h' : '--';

      return [
        DateFormat('dd MMM yyyy').format(date),
        site,
        supervisor,
        checkIn,
        checkOut,
        hoursStr,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellHeight: 24,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? '--' : value, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }
}
