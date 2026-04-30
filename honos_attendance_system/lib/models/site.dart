class Site {
  final String id, name, address, supervisorId;
  final double lat, lng, radius;

  const Site({
    required this.id, required this.name, required this.address,
    required this.lat, required this.lng, this.radius = 200,
    this.supervisorId = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'address': address,
    'lat': lat, 'lng': lng, 'radius': radius, 'supervisorId': supervisorId,
  };

  factory Site.fromJson(Map<String, dynamic> j) => Site(
    id: j['id'] ?? '', name: j['name'] ?? '', address: j['address'] ?? '',
    lat: (j['lat'] ?? 0).toDouble(), lng: (j['lng'] ?? 0).toDouble(),
    radius: (j['radius'] ?? 200).toDouble(), supervisorId: j['supervisorId'] ?? '',
  );
}
