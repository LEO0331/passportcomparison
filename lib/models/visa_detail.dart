// 在 main.dart 或 logic 控制層中
Map<String, List<String>> generateComparisonMatrix(
  List<String> allCountryNames, // 全球所有國家的清單
  Map<String, Set<String>>
  visaFreeSets, // 格式：{ "護照A": {"目的地1", "目的地2"}, "護照B": {...} }
) {
  Map<String, List<String>> matrix = {};

  for (var targetCountry in allCountryNames) {
    List<String> statuses = [];
    for (var passportName in visaFreeSets.keys) {
      // 檢查該目的地是否在該護照的免簽名單中
      bool isFree = visaFreeSets[passportName]!.contains(targetCountry);
      statuses.add(isFree ? "FREE" : "REQUIRED");
    }
    matrix[targetCountry] = statuses;
  }
  return matrix;
}
