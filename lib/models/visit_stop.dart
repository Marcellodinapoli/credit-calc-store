class VisitStop {
  const VisitStop({
    required this.id,
    required this.clientName,
    required this.address,
    this.latitude,
    this.longitude,
    this.sortOrder = 0,
    this.visited = false,
  });

  final String id;
  final String clientName;
  final String address;
  final double? latitude;
  final double? longitude;
  final int sortOrder;
  final bool visited;

  bool get hasCoordinates => latitude != null && longitude != null;

  VisitStop copyWith({
    String? clientName,
    String? address,
    double? latitude,
    double? longitude,
    int? sortOrder,
    bool? visited,
    bool clearCoordinates = false,
  }) {
    return VisitStop(
      id: id,
      clientName: clientName ?? this.clientName,
      address: address ?? this.address,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      sortOrder: sortOrder ?? this.sortOrder,
      visited: visited ?? this.visited,
    );
  }

  factory VisitStop.fromMap(String id, Map<String, dynamic> data) {
    return VisitStop(
      id: id,
      clientName: (data['clientName'] as String? ?? '').trim(),
      address: (data['address'] as String? ?? '').trim(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      visited: data['visited'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'sortOrder': sortOrder,
      'visited': visited,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
