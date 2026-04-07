import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:screenshot/screenshot.dart';
import '../models/country.dart';

class ComparisonTable extends StatefulWidget {
  final List<String> selectedCodes;
  final List<Country> allCountries;
  final Map<String, Set<String>> visaFreeMap;
  final ScreenshotController? screenshotController;

  const ComparisonTable({
    super.key,
    required this.selectedCodes,
    required this.allCountries,
    required this.visaFreeMap,
    this.screenshotController,
  });

  @override
  State<ComparisonTable> createState() => _ComparisonTableState();
}

class _ComparisonTableState extends State<ComparisonTable> {
  String _searchQuery = "";
  bool _showDifferencesOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePassports = widget.selectedCodes
        .map((code) => widget.allCountries.firstWhere((c) => c.code == code))
        .toList();

    Iterable<Country> filtered = widget.allCountries.where(
      (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
    );

    if (_showDifferencesOnly && activePassports.length > 1) {
      filtered = filtered.where((target) {
        final statuses = activePassports.map((p) {
          return (p.code == target.code) ||
              (widget.visaFreeMap[p.code]?.contains(target.code) ?? false);
        }).toSet();
        return statuses.length > 1;
      });
    }

    final filteredDestinations = filtered.toList();

    Widget tableContent = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search destination...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterChip(
                    label: const Text(
                      "Diff Only",
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _showDifferencesOnly,
                    onSelected: (val) =>
                        setState(() => _showDifferencesOnly = val),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selectedColor: const Color(
                      0xFFD86A55,
                    ).withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: StickyHeader(
                header: _buildStickyHeader(activePassports),
                content: Container(
                  color: theme.colorScheme.surface,
                  child: Table(
                    border: TableBorder.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {0: FlexColumnWidth(2.5)},
                    children: filteredDestinations.map((target) {
                      return TableRow(
                        decoration: BoxDecoration(
                          color: filteredDestinations.indexOf(target).isEven
                              ? theme.colorScheme.surface
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.12),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              target.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...activePassports.map((passport) {
                            return _buildStatusCell(passport, target);
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.screenshotController != null) {
      return Screenshot(
        controller: widget.screenshotController!,
        child: tableContent,
      );
    }

    return tableContent;
  }

  Widget _buildStickyHeader(List<Country> passports) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2A2F), Color(0xFF2D444A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.white.withValues(alpha: 0.18)),
        columnWidths: const {0: FlexColumnWidth(2.5)},
        children: [
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                  "Destination",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF4EFE7),
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              ...passports.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        elevation: 1,
                        borderRadius: BorderRadius.circular(4),
                        clipBehavior: Clip.antiAlias,
                        child: CountryFlag.fromCountryCode(
                          p.code.toUpperCase(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF8F4EC),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(Country passport, Country target) {
    if (!passport.hasData) {
      return Container(
        height: 40,
        color: Colors.grey.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Text(
          "N/A",
          style: TextStyle(color: Colors.grey, fontSize: 10),
        ),
      );
    }

    final isFree =
        (passport.code == target.code) ||
        (widget.visaFreeMap[passport.code]?.contains(target.code) ?? false);

    final color = isFree ? const Color(0xFF2E7D5A) : const Color(0xFFB33A3A);

    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Icon(
        isFree ? Icons.check_circle : Icons.cancel_outlined,
        color: color,
        size: 18,
      ),
    );
  }
}
