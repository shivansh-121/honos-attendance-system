class Attendance {
  final String id, guardId, siteId, date, time, status, photoPath, supervisorId, markedAt;
  final String checkOutTime, checkOutPhotoPath, checkOutSiteId;
  final double lat, lng;

  const Attendance({
    required this.id, required this.guardId, required this.siteId,
    required this.date, required this.time, required this.status,
    this.photoPath = '', this.supervisorId = '', this.markedAt = '',
    this.checkOutTime = '', this.checkOutPhotoPath = '', this.checkOutSiteId = '',
    this.lat = 0, this.lng = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'guardId': guardId, 'siteId': siteId, 'date': date,
    'time': time, 'status': status, 'photoPath': photoPath,
    'supervisorId': supervisorId, 'markedAt': markedAt, 
    'checkOutTime': checkOutTime, 'checkOutPhotoPath': checkOutPhotoPath, 'checkOutSiteId': checkOutSiteId,
    'lat': lat, 'lng': lng,
  };

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
    id: j['id'] ?? '', guardId: j['guardId'] ?? '', siteId: j['siteId'] ?? '',
    date: j['date'] ?? '', time: j['time'] ?? '', status: j['status'] ?? '',
    photoPath: j['photoPath'] ?? '', supervisorId: j['supervisorId'] ?? '',
    markedAt: j['markedAt'] ?? '',
    checkOutTime: j['checkOutTime'] ?? '', checkOutPhotoPath: j['checkOutPhotoPath'] ?? '', checkOutSiteId: j['checkOutSiteId'] ?? '',
    lat: (j['lat'] ?? 0).toDouble(), lng: (j['lng'] ?? 0).toDouble(),
  );
}
