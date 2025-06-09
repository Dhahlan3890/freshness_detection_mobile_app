class ScanResult {
  final String imagePath;
  final String prediction;
  final DateTime timestamp;
  final double confidence;

  ScanResult({
    required this.imagePath,
    required this.prediction,
    required this.timestamp,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'image': imagePath,
      'result': prediction,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
    };
  }

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      imagePath: json['image'] as String,
      prediction: json['result'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : 0.0,
    );
  }
}
