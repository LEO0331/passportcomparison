import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/comparison_session.dart';
import 'models/entry_requirements.dart';
import 'models/travel_access_comparison.dart';
import 'services/comparison_report.dart';
import 'services/dataset_repository.dart';
import 'widgets/travel_access_results.dart';

const _favoritesKey = 'favorites_list';
const _shareParameter = 'passports';
const _publicApp = 'https://leo0331.github.io/passportcomparison/';

void main() => runApp(const PassportComparisonApp());

class PassportComparisonApp extends StatefulWidget {
  const PassportComparisonApp({super.key});

  @override
  State<PassportComparisonApp> createState() => _PassportComparisonAppState();
}

class _PassportComparisonAppState extends State<PassportComparisonApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB34A32),
      brightness: brightness,
      primary: dark ? const Color(0xFFE38A6F) : const Color(0xFF803827),
      surface: dark ? const Color(0xFF161C1F) : const Color(0xFFF5EFE6),
      onSurface: dark ? const Color(0xFFF3EDE4) : const Color(0xFF201A18),
    );
    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Passport Comparison',
    debugShowCheckedModeBanner: false,
    themeMode: _themeMode,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: PassportComparePage(
      onToggleTheme: () => setState(() {
        _themeMode = _themeMode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      }),
    ),
  );
}

class PassportComparePage extends StatefulWidget {
  const PassportComparePage({
    super.key,
    this.loadDataset,
    this.initialUri,
    this.onToggleTheme,
  });

  final Future<PassportDataset> Function()? loadDataset;
  final Uri? initialUri;
  final VoidCallback? onToggleTheme;

  @override
  State<PassportComparePage> createState() => _PassportComparePageState();
}

class _PassportComparePageState extends State<PassportComparePage> {
  final _screenshot = ScreenshotController();
  final _favorites = <FavoriteSnapshot>[];
  List<String?> _codes = [null, null];
  PassportDataset? _dataset;
  TravelAccessComparison? _comparison;
  SharedPreferences? _preferences;
  bool _loading = true;
  bool _invalidLink = false;
  bool _exporting = false;
  bool _writingPreset = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPresets();
  }

  Future<void> _load() async {
    try {
      final dataset = await (widget.loadDataset ?? DatasetRepository().load)();
      if (!mounted) return;
      final parameters = (widget.initialUri ?? Uri.base).queryParametersAll;
      final supplied = parameters[_shareParameter];
      final codes = supplied != null && supplied.length == 1
          ? supplied.single.split(',')
          : null;
      setState(() {
        _dataset = dataset;
        _loading = false;
        if (codes != null &&
            codes.length >= 2 &&
            codes.length <= 5 &&
            codes.toSet().length == codes.length &&
            codes.every(dataset.passports.containsKey)) {
          _codes = [...codes];
          _updateComparison();
        } else {
          _invalidLink = supplied != null;
        }
      });
    } catch (error, stack) {
      debugPrint('Bundled dataset load failed: $error\n$stack');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = <FavoriteSnapshot>[];
      final payload = prefs.getString(_favoritesKey);
      if (payload != null) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is List) {
            for (final item in decoded.whereType<Map<String, dynamic>>()) {
              try {
                favorites.add(
                  FavoriteSnapshot.fromJson(item, fallbackYear: ''),
                );
              } on TypeError {
                continue;
              }
            }
          }
        } on FormatException {
          debugPrint('Saved comparisons could not be read.');
        }
      }
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _favorites.addAll(favorites);
      });
    } catch (error) {
      debugPrint('Saved comparisons are unavailable: $error');
    }
  }

  void _updateComparison() {
    final selected = _codes.whereType<String>().toList();
    _comparison = selected.length == _codes.length
        ? TravelAccessComparison.calculate(_dataset!, selected)
        : null;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectPassport(int index) async {
    final locale = View.of(context).platformDispatcher.locale.toLanguageTag();
    final available =
        _dataset!.passports.values
            .where(
              (passport) =>
                  !_codes.contains(passport.code) ||
                  _codes[index] == passport.code,
            )
            .toList()
          ..sort((a, b) => a.nameFor(locale).compareTo(b.nameFor(locale)));
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _PassportSearch(
        slot: _slot(index),
        passports: available,
        locale: locale,
      ),
    );
    if (!mounted || code == null) return;
    setState(() {
      _invalidLink = false;
      _codes[index] = code;
      _updateComparison();
    });
  }

  static String _slot(int index) => String.fromCharCode(65 + index);

  Future<bool> _writePresets(List<FavoriteSnapshot> favorites) async {
    if (_writingPreset) return false;
    _writingPreset = true;
    try {
      final saved = await _preferences!.setString(
        _favoritesKey,
        jsonEncode(favorites.map((favorite) => favorite.toJson()).toList()),
      );
      if (saved) return true;
    } catch (error) {
      debugPrint('Could not write saved comparisons: $error');
    } finally {
      _writingPreset = false;
    }
    _message('Could not update saved comparisons on this device.');
    return false;
  }

  Future<void> _savePreset(TravelAccessComparison comparison) async {
    final defaultTitle = comparison.passports.map((p) => p.name).join(' / ');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _PresetTitleDialog(initialTitle: defaultTitle),
    );
    if (title == null || !mounted) return;
    final favorite = FavoriteSnapshot(
      title: title,
      date: DateTime.now().toIso8601String().substring(0, 10),
      count: comparison.passports.length,
      selections: [
        for (final passport in comparison.passports)
          PassportSelection(countryCode: passport.code, year: ''),
      ],
    );
    if (await _writePresets([..._favorites, favorite]) && mounted) {
      setState(() => _favorites.add(favorite));
      _message('Comparison preset saved.');
    }
  }

  Future<void> _showPresets() async {
    final item = await showDialog<FavoriteSnapshot>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Saved presets'),
          content: SizedBox(
            width: 440,
            child: _favorites.isEmpty
                ? const Text('Saved comparisons will appear here.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final favorite = _favorites[index];
                      return ListTile(
                        title: Text(favorite.title),
                        subtitle: Text(
                          '${favorite.activeCodes.join(" · ")} • ${favorite.date}',
                        ),
                        onTap: () => Navigator.pop(context, favorite),
                        trailing: IconButton(
                          tooltip: 'Remove ${favorite.title}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final remaining = [..._favorites]..remove(favorite);
                            if (await _writePresets(remaining) && mounted) {
                              setState(() => _favorites.remove(favorite));
                              if (context.mounted) updateDialog(() {});
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (item == null || !mounted) return;
    final seen = <String>{};
    final supported = item.activeCodes
        .map((code) => code.trim().toUpperCase())
        .where(_dataset!.passports.containsKey)
        .where(seen.add)
        .toList();
    setState(() {
      _invalidLink = false;
      _codes = [
        ...supported,
        ...List<String?>.filled(
          (item.count.clamp(2, 5) - supported.length).clamp(0, 5),
          null,
        ),
      ];
      _updateComparison();
    });
    if (supported.length != item.activeCodes.length) {
      _message('Some passports in this preset are unavailable or duplicated.');
    }
  }

  Future<void> _copyLink(TravelAccessComparison comparison) async {
    final base = kIsWeb ? Uri.base : Uri.parse(_publicApp);
    final link = base.removeFragment().replace(
      queryParameters: {
        _shareParameter: comparison.passports.map((p) => p.code).join(','),
      },
    );
    try {
      await Clipboard.setData(ClipboardData(text: link.toString()));
      _message('Comparison link copied.');
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Comparison link'),
          content: SelectableText(link.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _shareScreenshot(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final bytes = await _screenshot.capture();
      if (bytes == null) throw StateError('No screenshot available.');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['passport-comparison.png'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      _message('Could not share the comparison screenshot.');
    }
  }

  Future<void> _export(
    TravelAccessComparison comparison,
    bool differences,
  ) async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildComparisonPdf(
        comparison,
        differencesOnly: differences,
      );
      if (!mounted) return;
      final name = differences
          ? 'passport-differences.pdf'
          : 'passport-comparison.pdf';
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(name: name, onLayout: (_) => bytes);
      }
    } catch (error) {
      debugPrint('Report export failed: $error');
      _message('Could not export the comparison report.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataset = _dataset;
    final comparison = _comparison;
    final locale = View.of(context).platformDispatcher.locale.toLanguageTag();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport Comparison'),
        actions: [
          IconButton(
            tooltip: 'Saved presets',
            onPressed: dataset == null || _preferences == null
                ? null
                : _showPresets,
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: 'Change color theme',
              onPressed: widget.onToggleTheme,
              icon: const Icon(Icons.contrast),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading travel data',
              ),
            )
          : dataset == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Travel data is temporarily unavailable.'),
                  TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Passport Access Difference Analyzer',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose passports to compare how entry requirements differ.',
                        ),
                        if (_invalidLink)
                          const Text(
                            'This link contains unsupported passport selections. Choose passports below.',
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var index = 0; index < _codes.length; index++)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _selectPassport(index),
                                    child: Text(
                                      dataset.passports[_codes[index]] != null
                                          ? 'Passport ${_slot(index)}: ${dataset.passports[_codes[index]]!.nameFor(locale)}'
                                          : 'Passport ${_slot(index)}',
                                    ),
                                  ),
                                  if (_codes.length > 2)
                                    IconButton(
                                      tooltip:
                                          'Remove passport ${_slot(index)}',
                                      onPressed: () => setState(() {
                                        _codes.removeAt(index);
                                        _updateComparison();
                                      }),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                ],
                              ),
                            if (_codes.length < 5)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _codes.add(null);
                                  _updateComparison();
                                }),
                                icon: const Icon(Icons.add),
                                label: const Text('Add passport'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AboutTravelData(metadata: dataset.metadata),
                        if (comparison != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: _preferences == null
                                    ? null
                                    : () => _savePreset(comparison),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                label: const Text('Save preset'),
                              ),
                              TextButton.icon(
                                onPressed: () => _copyLink(comparison),
                                icon: const Icon(Icons.link),
                                label: const Text('Copy comparison link'),
                              ),
                              Builder(
                                builder: (context) => IconButton(
                                  tooltip: 'Share screenshot',
                                  onPressed: () => _shareScreenshot(context),
                                  icon: const Icon(Icons.image_outlined),
                                ),
                              ),
                              PopupMenuButton<bool>(
                                enabled: !_exporting,
                                tooltip: 'Export PDF',
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                onSelected: (differences) =>
                                    _export(comparison, differences),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: false,
                                    child: Text('Full comparison PDF'),
                                  ),
                                  PopupMenuItem(
                                    value: true,
                                    child: Text('Differences-only PDF'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Screenshot(
                            controller: _screenshot,
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: TravelAccessResults(
                                key: ValueKey(_codes.join(',')),
                                comparison: comparison,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PassportSearch extends StatefulWidget {
  const _PassportSearch({
    required this.slot,
    required this.passports,
    required this.locale,
  });

  final String slot;
  final List<Passport> passports;
  final String locale;

  @override
  State<_PassportSearch> createState() => _PassportSearchState();
}

class _PassportSearchState extends State<_PassportSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.passports
        .where(
          (passport) =>
              passport.name.toLowerCase().contains(_query) ||
              passport.nameFor(widget.locale).toLowerCase().contains(_query) ||
              passport.code.toLowerCase().startsWith(_query),
        )
        .toList();
    return AlertDialog(
      title: Text('Select passport ${widget.slot}'),
      content: SizedBox(
        width: 400,
        height: 340,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Search passports'),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              onSubmitted: (_) {
                if (matches.isNotEmpty) {
                  Navigator.pop(context, matches.first.code);
                }
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No passports found.'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final passport = matches[index];
                        return Semantics(
                          button: true,
                          child: ListTile(
                            title: Text(passport.nameFor(widget.locale)),
                            onTap: () => Navigator.pop(context, passport.code),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PresetTitleDialog extends StatefulWidget {
  const _PresetTitleDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_PresetTitleDialog> createState() => _PresetTitleDialogState();
}

class _PresetTitleDialogState extends State<_PresetTitleDialog> {
  late String _title = widget.initialTitle;

  void _save() {
    final title = _title.trim();
    Navigator.pop(context, title.isEmpty ? widget.initialTitle : title);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save comparison preset'),
    content: TextFormField(
      autofocus: true,
      initialValue: widget.initialTitle,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Comparison title'),
      onChanged: (value) => _title = value,
      onFieldSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
