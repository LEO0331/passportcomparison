class Country {
  final String code;
  final String name;
  final String region;
  final double openness;
  final bool hasData;
  final Map<String, dynamic>? yearlyData;

  Country({
    required this.code,
    required this.name,
    required this.region,
    required this.openness,
    required this.hasData,
    this.yearlyData,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    bool hasData = json['has_data'] == true;

    return Country(
      code: json['code'] ?? '',
      name: json['country'] ?? 'Unknown',
      region: json['region'] ?? 'Unknown', // 從 JSON 的 'region' 獲取
      // 處理數值轉型：API 回傳可能是 int 或 double，統一轉為 double
      openness: (json['openness'] ?? 0.0).toDouble(),
      hasData: hasData,
      // 核心邏輯：只有 hasData 為 true 且 json['data'] 是 Map 時才賦值
      yearlyData: (hasData && json['data'] is Map) ? json['data'] : null,
    );
  }
}
