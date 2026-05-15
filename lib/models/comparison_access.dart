bool isAccessibleDestination({
  required String passportCode,
  required String destinationCode,
  required Map<String, Set<String>> visaFreeMap,
}) {
  return passportCode == destinationCode ||
      (visaFreeMap[passportCode]?.contains(destinationCode) ?? false);
}

bool hasDifferentAccess({
  required List<String> passportCodes,
  required String destinationCode,
  required Map<String, Set<String>> visaFreeMap,
}) {
  final statuses = passportCodes
      .map(
        (passportCode) => isAccessibleDestination(
          passportCode: passportCode,
          destinationCode: destinationCode,
          visaFreeMap: visaFreeMap,
        ),
      )
      .toSet();
  return statuses.length > 1;
}
