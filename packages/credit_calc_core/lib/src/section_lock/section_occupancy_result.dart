class SectionOccupancyResult {
  const SectionOccupancyResult({
    required this.allowed,
    this.deviceLabel,
    this.deviceType,
    this.message,
  });

  final bool allowed;
  final String? deviceLabel;
  final String? deviceType;
  final String? message;

  static const allowedFree = SectionOccupancyResult(allowed: true);
}
