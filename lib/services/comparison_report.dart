import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/entry_requirements.dart';
import '../models/travel_access_comparison.dart';

const _fontAsset = 'assets/fonts/PassportReportSans.ttf';

Future<Uint8List> buildComparisonPdf(
  TravelAccessComparison comparison, {
  bool differencesOnly = false,
}) async {
  if (comparison.rows.isEmpty) {
    throw StateError('There are no destination records to report.');
  }

  final font = pw.Font.ttf(await rootBundle.load(_fontAsset));
  final report = pw.Document(
    title: 'Passport Access Comparison',
    author: 'Passport Comparison',
    theme: pw.ThemeData.withFont(base: font),
  );
  final metadata = comparison.metadata;
  final rows = comparison.filteredRows(
    filter: differencesOnly
        ? ComparisonFilter.differences
        : ComparisonFilter.all,
  );
  final verificationDates = [
    if (metadata.oldestVerified != null) metadata.oldestVerified!,
    if (metadata.newestVerified != null &&
        metadata.newestVerified != metadata.oldestVerified)
      metadata.newestVerified!,
  ];

  report.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 40,
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Passport Comparison  |  Dataset ${metadata.version}'),
            pw.Text('${context.pageNumber} / ${context.pagesCount}'),
          ],
        ),
      ),
      build: (context) => [
        pw.Text(
          'Passport Access Comparison',
          style: const pw.TextStyle(fontSize: 24, color: PdfColors.blueGrey900),
        ),
        pw.Text(
          differencesOnly
              ? 'Different confirmed categories'
              : 'All destinations',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey700),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          comparison.passports
              .map((passport) => '${passport.name} (${passport.code})')
              .join('  /  '),
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _metric('Shared visa-free access', comparison.sharedVisaFree),
            _metric('Combined visa-free access', comparison.combinedVisaFree),
            _metric('Different categories', comparison.differentCategories),
            _metric('Visa-free differences', comparison.visaFreeDifferences),
            _metric('With unconfirmed data', comparison.unknown),
          ],
        ),
        if (comparison.passports.length == 2) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            comparison.passports
                .map((passport) {
                  final count =
                      comparison.visaFreeOnlyByPassport[passport.code];
                  return 'Visa-free with ${passport.name} only: $count';
                })
                .join('   |   '),
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          'Shared access means every selected passport qualifies. Combined '
          'access means at least one qualifies and can help travelers who '
          'legally hold multiple passports. Summary counts cover all destinations.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.UrlLink(
          destination: metadata.sourceUrl.toString(),
          child: pw.Text(
            metadata.attribution,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue800),
          ),
        ),
        pw.Text(
          'Dataset version ${metadata.version}  |  License ${metadata.license}  |  '
          'Source verification ${verificationDates.isEmpty ? 'unavailable' : verificationDates.join(' to ')}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Entry requirements may change. Verify the official requirements '
          'before travel. An entry category does not guarantee admission.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 14),
        _categoryGuide(),
        pw.SizedBox(height: 14),
        pw.Text(
          'Destination requirements',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.Text(
          '${rows.length} ${rows.length == 1 ? 'destination' : 'destinations'} '
          'in this report. Dates shown in individual '
          'cells reflect the cited source verification. Category links open '
          'the source when available.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text('No destinations have different confirmed categories.')
        else
          _requirementsTable(comparison.passports, rows),
      ],
    ),
  );
  return report.save();
}

pw.Widget _metric(String label, int count) => pw.Container(
  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  child: pw.Text('$label: $count', style: const pw.TextStyle(fontSize: 9)),
);

pw.Table _requirementsTable(
  List<Passport> passports,
  List<DestinationComparison> rows,
) => pw.Table(
  columnWidths: const {0: pw.FlexColumnWidth(1.25)},
  border: const pw.TableBorder(
    horizontalInside: pw.BorderSide(color: PdfColors.blueGrey200, width: .4),
  ),
  defaultColumnWidth: const pw.FlexColumnWidth(),
  children: [
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      children: [
        _headerCell('Destination'),
        for (final passport in passports)
          _headerCell('${passport.name} (${passport.code})'),
      ],
    ),
    for (final row in rows)
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              '${row.destination.name} (${row.destination.code})',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          for (final requirement in row.requirements)
            _requirementCell(requirement),
        ],
      ),
  ],
);

pw.Widget _headerCell(String label) => pw.Padding(
  padding: const pw.EdgeInsets.all(5),
  child: pw.Text(
    label,
    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
  ),
);

pw.Widget _requirementCell(EntryRequirement entry) {
  final source = entry.source;
  final category = pw.Text(
    entry.type.label,
    style: pw.TextStyle(
      fontSize: 9,
      color: source == null ? PdfColors.blueGrey900 : PdfColors.blue800,
    ),
  );
  final context = [
    if (entry.isConditional) 'Check eligibility',
    if (entry.stay case final stay?)
      stay.length <= 42 ? stay : 'See source for stay rules',
    if (entry.validUntil != null) 'Policy end date ${entry.validUntil}',
    if (entry.verified != null) entry.verified!,
    if (entry.sourceLevel != null) entry.sourceLevel!.label,
  ];
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        source == null
            ? category
            : pw.UrlLink(destination: source.url.toString(), child: category),
        if (context.isNotEmpty)
          pw.Text(
            context.join('  |  '),
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.blueGrey700,
            ),
          ),
      ],
    ),
  );
}

pw.Widget _categoryGuide() {
  final types = RequirementType.values;
  final split = (types.length + 1) ~/ 2;
  pw.Widget column(Iterable<RequirementType> entries) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final type in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              '${type.label}  |  ${_meaning(type)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
      ],
    ),
  );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Category guide', style: const pw.TextStyle(fontSize: 14)),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          column(types.take(split)),
          pw.SizedBox(width: 14),
          column(types.skip(split)),
        ],
      ),
    ],
  );
}

String _meaning(RequirementType type) => switch (type) {
  RequirementType.visaFree => 'No visa for the qualifying stay.',
  RequirementType.visaOnArrival =>
    'Visa issued on arrival, subject to eligibility.',
  RequirementType.eta => 'Electronic authorization before travel.',
  RequirementType.evisa => 'Visa obtained electronically before travel.',
  RequirementType.embassyVisa =>
    'Visa obtained through an embassy or consulate.',
  RequirementType.visaRequired =>
    'Visa required before travel. Check the application channel.',
  RequirementType.freedomOfMovement =>
    'Access under a freedom-of-movement arrangement.',
  RequirementType.travelPermit =>
    'A travel permit applies. Check its rules and eligibility.',
  RequirementType.banned => 'The dataset reports an entry restriction.',
  RequirementType.unconfirmed => 'A confirmed category is unavailable.',
};
