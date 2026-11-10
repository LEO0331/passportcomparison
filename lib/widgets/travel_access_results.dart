import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/entry_requirements.dart';
import '../models/travel_access_comparison.dart';

class TravelAccessResults extends StatefulWidget {
  final TravelAccessComparison comparison;

  const TravelAccessResults({super.key, required this.comparison});

  @override
  State<TravelAccessResults> createState() => _TravelAccessResultsState();
}

class _TravelAccessResultsState extends State<TravelAccessResults> {
  static const _pageSize = 15;
  ComparisonFilter _filter = ComparisonFilter.all;
  String? _region;
  String _query = '';
  int _page = 0;

  @override
  void didUpdateWidget(covariant TravelAccessResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comparison != widget.comparison) {
      _page = 0;
      if (!widget.comparison.rows.any(
        (row) => row.destination.region == _region,
      )) {
        _region = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = View.of(context).platformDispatcher.locale.toLanguageTag();
    final comparison = widget.comparison;
    final regions =
        comparison.rows.map((row) => row.destination.region).toSet().toList()
          ..sort();
    final filtered = comparison.filteredRows(
      filter: _filter,
      region: _region,
      query: _query,
      locale: locale,
    );
    final offset = _page * _pageSize;
    final visible = filtered.skip(offset).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccessSummary(comparison: comparison, locale: locale),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            'Destination comparison',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Open a destination to see conditions, stay limits and sources.',
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search destinations',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (query) => setState(() {
            _query = query;
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 222,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Show',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ComparisonFilter>(
                    isExpanded: true,
                    isDense: true,
                    value: _filter,
                    items: const [
                      DropdownMenuItem(
                        value: ComparisonFilter.all,
                        child: Text('All destinations'),
                      ),
                      DropdownMenuItem(
                        value: ComparisonFilter.differences,
                        child: Text('Differences only'),
                      ),
                      DropdownMenuItem(
                        value: ComparisonFilter.visaFreeDifferences,
                        child: Text('Visa-free differences'),
                      ),
                    ],
                    onChanged: (filter) {
                      if (filter == null) return;
                      setState(() {
                        _filter = filter;
                        _page = 0;
                      });
                    },
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 222,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Region',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: _region ?? '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All regions'),
                      ),
                      for (final region in regions)
                        DropdownMenuItem(
                          value: region,
                          child: Text(region, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (region) => setState(() {
                      _region = region == '' ? null : region;
                      _page = 0;
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No destinations match these filters.'),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final useTable =
                  constraints.maxWidth >=
                  170 + 116 * comparison.passports.length;
              return useTable
                  ? _destinationTable(context, visible, locale)
                  : _destinationCards(visible, locale);
            },
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${offset + 1}–${offset + visible.length} of ${filtered.length} destinations',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous destinations',
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next destinations',
                onPressed: offset + visible.length < filtered.length
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _destinationTable(
    BuildContext context,
    List<DestinationComparison> rows,
    String locale,
  ) {
    final colors = Theme.of(context).colorScheme;
    final passports = widget.comparison.passports;
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.35)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: colors.outlineVariant),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.surfaceContainerHighest),
          children: [
            const _TableHeading('Destination'),
            for (final passport in passports)
              _TableHeading(passport.nameFor(locale)),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => _openDestination(row, locale),
                  child: Text(row.destination.nameFor(locale)),
                ),
              ),
              for (var i = 0; i < passports.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: _RequirementLabel(
                    requirement: row.requirements[i],
                    passportName: passports[i].nameFor(locale),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _destinationCards(List<DestinationComparison> rows, String locale) {
    final passports = widget.comparison.passports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Card.outlined(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => _openDestination(row, locale),
                      child: Text(row.destination.nameFor(locale)),
                    ),
                  ),
                  for (var i = 0; i < passports.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ExcludeSemantics(
                              child: Text(passports[i].nameFor(locale)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _RequirementLabel(
                              requirement: row.requirements[i],
                              passportName: passports[i].nameFor(locale),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _openDestination(DestinationComparison row, String locale) {
    final comparison = widget.comparison;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.destination.nameFor(locale)),
        scrollable: true,
        content: SizedBox(
          width: 540,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < comparison.passports.length; i++) ...[
                _RequirementDetails(
                  passportName: comparison.passports[i].nameFor(locale),
                  requirement: row.requirements[i],
                ),
                const Divider(height: 26),
              ],
              const Text(
                'Entry rules can change. Verify the official requirements before travel.',
              ),
              const SizedBox(height: 8),
              Text(
                comparison.metadata.attribution,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  final String label;

  const _TableHeading(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Semantics(
      header: true,
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _AccessSummary extends StatelessWidget {
  final TravelAccessComparison comparison;
  final String locale;

  const _AccessSummary({required this.comparison, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <(String, int)>[
      ('Shared visa-free access', comparison.sharedVisaFree),
      ('Combined visa-free access', comparison.combinedVisaFree),
      ('Different requirement categories', comparison.differentCategories),
      ('Requirement not confirmed', comparison.unknown),
      if (comparison.passports.length == 2)
        for (final passport in comparison.passports)
          (
            'Visa-free with ${passport.nameFor(locale)} only',
            comparison.visaFreeOnlyByPassport[passport.code] ?? 0,
          ),
      if (comparison.passports.length > 2)
        ('Visa-free differences', comparison.visaFreeDifferences),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Travel access summary',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          comparison.passports
              .map((passport) => passport.nameFor(locale))
              .join(' · '),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 660
                ? 3
                : constraints.maxWidth >= 340
                ? 2
                : 1;
            const gap = 8.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (label, count) in counts)
                  SizedBox(
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Semantics(
                          label: '$label, $count destinations',
                          excludeSemantics: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$count',
                                style: theme.textTheme.headlineSmall,
                              ),
                              Text(label),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Shared access requires confirmed visa-free access for every selected passport and can help group travelers. Combined access requires it for at least one passport and is relevant if you legally hold multiple passports. Destination authorities decide entry.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'The comparison excludes the selected passports’ home destinations. Conditional exemptions are shown in the table and kept separate from confirmed visa-free access.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Difference counts compare known categories. Destinations with missing or unconfirmed information are counted separately.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _RequirementLabel extends StatelessWidget {
  final EntryRequirement requirement;
  final String? passportName;

  const _RequirementLabel({required this.requirement, this.passportName});

  @override
  Widget build(BuildContext context) {
    final category = requirement.type;
    final icon = switch (category) {
      RequirementType.visaFree => Icons.check_circle_outline,
      RequirementType.visaOnArrival => Icons.flight_land,
      RequirementType.eta || RequirementType.evisa => Icons.devices_outlined,
      RequirementType.embassyVisa ||
      RequirementType.visaRequired => Icons.description_outlined,
      RequirementType.freedomOfMovement => Icons.swap_horiz,
      RequirementType.travelPermit => Icons.assignment_outlined,
      RequirementType.banned => Icons.block,
      RequirementType.unconfirmed => Icons.help_outline,
    };
    final label = requirement.isConditional
        ? '${category.label} · Conditions apply'
        : category.label;
    return Semantics(
      label: passportName == null ? label : '$passportName, $label',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _RequirementDetails extends StatelessWidget {
  final String passportName;
  final EntryRequirement requirement;

  const _RequirementDetails({
    required this.passportName,
    required this.requirement,
  });

  @override
  Widget build(BuildContext context) {
    final stay = requirement.stay;
    final conditions = requirement.conditions;
    final verified = requirement.verified;
    final validUntil = requirement.validUntil;
    final source = requirement.source;
    final provenance = source?.provenance;
    final sourceLevel = requirement.sourceLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            passportName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 4),
        _RequirementLabel(requirement: requirement),
        if (stay != null && stay.isNotEmpty && !requirement.isExpired)
          Text('Maximum stay of $stay'),
        if (validUntil != null)
          Text(
            requirement.isExpired
                ? 'Published rule expired on $validUntil'
                : 'Published rule valid through $validUntil',
          ),
        if (conditions != null && conditions.isNotEmpty) Text(conditions),
        if (verified != null) Text('Source verified on $verified'),
        if (sourceLevel != null) Text(sourceLevel.label),
        if (provenance != null) Text(_provenanceLabel(provenance)),
        if (source != null)
          _SourceLink(
            uri: source.url,
            label: source.name.isEmpty ? source.url.host : source.name,
          ),
      ],
    );
  }
}

String _provenanceLabel(String provenance) => switch (provenance) {
  'first-party' => 'Destination authority',
  'third-party-government' =>
    'Another government describing the destination’s rules',
  'designated-operator' => 'Designated operator',
  'intergovernmental' => 'Intergovernmental organization',
  _ => provenance,
};

class AboutTravelData extends StatelessWidget {
  final DatasetMetadata metadata;

  const AboutTravelData({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final oldest = metadata.oldestVerified;
    final newest = metadata.newestVerified;
    final latestDate = newest == null ? null : DateTime.tryParse(newest);
    final stale =
        latestDate != null &&
        DateTime.now().toUtc().difference(latestDate.toUtc()).inDays > 90;
    final updated = metadata.importedAt.split('T').first;
    return ExpansionTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('About the data'),
      subtitle: stale
          ? const Text('Latest source verification is over 90 days old')
          : Text('TravelRequirements.info · v${metadata.version}'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Dataset version ${metadata.version} · ${metadata.commit}'),
        Text('Bundled snapshot imported on $updated'),
        if (newest != null)
          Text(
            oldest == null
                ? 'Latest source verification $newest'
                : 'Source verification dates range from $oldest to $newest',
          )
        else
          const Text('Source verification dates unavailable'),
        Text(
          'Coverage includes ${metadata.passportCount} passports and ${metadata.destinationCount} destinations. The dataset contains ${metadata.recordCount} records and ${metadata.missingCount} missing pairs.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Passport-specific citations support individual records. Other records use a general destination policy citation. Missing and unconfirmed requirements stay unknown. Historical rankings are unavailable here.',
        ),
        const SizedBox(height: 8),
        const Text(
          'An electronic travel authorization and an electronic visa are separate processes. Visa on arrival is issued at entry. Freedom of movement, travel permits and entry restrictions each have their own rules.',
        ),
        const SizedBox(height: 8),
        Text(metadata.attribution),
        const Text(
          'Adapted for this comparison by normalizing entry categories and retaining relevant source fields.',
        ),
        _SourceLink(uri: metadata.sourceUrl, label: 'Dataset and methodology'),
        _SourceLink(
          uri: Uri.https('creativecommons.org', '/licenses/by/4.0/'),
          label: 'CC BY 4.0 license',
        ),
      ],
    );
  }
}

class _SourceLink extends StatelessWidget {
  final Uri uri;
  final String label;

  const _SourceLink({required this.uri, required this.label});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: uri.toString(),
    child: TextButton.icon(
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
      onPressed: () async {
        try {
          if (await launchUrl(uri, webOnlyWindowName: '_blank')) return;
        } on Exception {
          // Keep the address available when the platform cannot open it.
        }
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Source address'),
            content: SelectableText(uri.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
