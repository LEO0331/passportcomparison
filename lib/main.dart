// coverage:ignore-file
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:passportcomparison/widgets/openness_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/country.dart';
import 'models/comparison_access.dart';
import 'models/comparison_session.dart';
import 'services/api_service.dart';
import 'widgets/passport_input.dart';
import 'widgets/comparison_table.dart';
import 'package:country_flags/country_flags.dart';
import 'package:logger/logger.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void _noopThemeToggle() {}

const Key startButtonKey = ValueKey('start-button');
const Key compareButtonKey = ValueKey('compare-button');
const Key detailsButtonKey = ValueKey('details-button');
const Key addFavoriteButtonKey = ValueKey('add-favorite-button');
const Key resetAllButtonKey = ValueKey('reset-all-button');
const Key shareScreenshotButtonKey = ValueKey('share-screenshot-button');
const Key exportFullPdfButtonKey = ValueKey('export-full-pdf-button');
const Key exportDiffPdfButtonKey = ValueKey('export-diff-pdf-button');
const Key favoritesDrawerTileKey = ValueKey('favorites-drawer-tile');
const Key saveFavoriteDialogButtonKey = ValueKey('save-favorite-dialog-button');

void main() {
  runApp(const PassportComparisonApp());
}

class PassportComparisonApp extends StatefulWidget {
  const PassportComparisonApp({super.key});

  @override
  State<PassportComparisonApp> createState() => _PassportComparisonAppState();
}

class _PassportComparisonAppState extends State<PassportComparisonApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB34A32);
    final light = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: const Color(0xFF803827),
      surface: const Color(0xFFF5EFE6),
      onSurface: const Color(0xFF201A18),
    );
    final dark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: const Color(0xFFE38A6F),
      surface: const Color(0xFF161C1F),
      onSurface: const Color(0xFFF3EDE4),
    );

    ThemeData buildTheme(ColorScheme colors) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: colors.surface,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.1,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          bodyMedium: TextStyle(height: 1.35),
          labelLarge: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildTheme(light),
      darkTheme: buildTheme(dark),
      home: PassportComparePage(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class PassportComparePage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final ApiService? apiService;

  const PassportComparePage({
    super.key,
    this.themeMode = ThemeMode.dark,
    this.onToggleTheme = _noopThemeToggle,
    this.apiService,
  });

  @override
  State<PassportComparePage> createState() => _PassportComparePageState();
}

class _PassportComparePageState extends State<PassportComparePage> {
  late final ApiService _apiService;
  final _logger = Logger();
  static final String currentYear = DateTime.now().year.toString();
  final ScreenshotController _screenshotController = ScreenshotController();
  // 狀態變數
  List<Country> allCountries = [];
  bool hasInitialized = false;
  bool isLoadingInitial = false;
  bool isComparing = false;
  bool showDetails = false;
  bool isLoadingDetails = false;
  int _selectedIndex = 0; // 0: Home, 1: Favorites
  List<FavoriteSnapshot> _favorites = []; // 儲存我的最愛清單
  ComparisonSession _session = ComparisonSession.empty(
    defaultYear: currentYear,
  );

  Map<String, Set<String>> visaFreeMap = {};

  int get passportCount => _session.passportCount;

  List<PassportSelection> get _visibleSelections =>
      _session.selections.take(passportCount).toList();

  List<PassportSelection> get _activeSelections => _visibleSelections
      .where((selection) => selection.countryCode != null)
      .toList();

  void _logInfo(String message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  void _logWarn(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.w(message);
    }
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.e(message);
    }
  }

  // --- 分享截圖 ---
  Future<void> _shareScreenshot(ScreenshotController controller) async {
    try {
      final image = await controller.capture();
      if (image == null) return;
      if (kIsWeb) {
        // 在 Web 端，'share_plus' 的圖片分享有限制
        await Printing.sharePdf(
          bytes: image,
          filename: 'passport_comparison.png',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = await File(
          '${tempDir.path}/passport_comparison.png',
        ).create();
        await file.writeAsBytes(image);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Passport Comparison'),
        );
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      _logError("Share failed");
    }
  }

  // --- 導出 PDF ---
  Future<void> _exportToPdf({bool diffOnly = false}) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansTCRegular();
    final boldFont = await PdfGoogleFonts.notoSansTCBold();

    final activeSelections = _activeSelections;

    // --- 關鍵：過濾資料邏輯 ---
    // 我們只針對 Detailed Access 進行過濾
    final List<List<String>> tableData = [];

    for (var dest in allCountries) {
      // 取得每個選定國家對該目的地(dest)的簽證狀態 (true/false)
      final statuses = activeSelections.map((selection) {
        return isAccessibleDestination(
          passportCode: selection.countryCode!,
          destinationCode: dest.code,
          visaFreeMap: visaFreeMap,
        );
      }).toList();

      // 判斷是否「全等」：如果所有狀態都一樣，代表沒有差異
      // 如果 diffOnly 為 true，且全等，就跳過這一個國家
      if (diffOnly &&
          !hasDifferentAccess(
            passportCodes: activeSelections
                .map((selection) => selection.countryCode!)
                .toList(),
            destinationCode: dest.code,
            visaFreeMap: visaFreeMap,
          )) {
        continue;
      }

      // 否則，將這行加入表格
      tableData.add([
        dest.name,
        ...statuses.map((isVisaFree) => isVisaFree ? "V" : "X"),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              diffOnly
                  ? "Passport Comparison (Differences Only)"
                  : "Full Passport Comparison Report",
              style: pw.TextStyle(font: boldFont, fontSize: 22),
            ),
          ),
          pw.SizedBox(height: 10),

          // 1. Summary Section (保持顯示所有選定國家)
          pw.Text(
            "Selected Passports",
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Country', 'Year', 'Rank', 'Total'],
            headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey700,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            data: activeSelections.map((selection) {
              final country = allCountries.firstWhere(
                (c) => c.code == selection.countryCode,
              );
              final stats = country.yearlyData?[selection.year];
              return [
                country.name,
                selection.year,
                "#${stats?['rank'] ?? 'N/A'}",
                stats?['total']?.toString() ?? '0',
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 25),

          // 2. Detailed Diff Section
          pw.Text(
            diffOnly ? "Visa Access Differences" : "All Destination Access",
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
          pw.SizedBox(height: 10),

          if (tableData.isEmpty)
            pw.Center(
              child: pw.Text(
                "No differences found between selected passports.",
                style: pw.TextStyle(font: font),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Destination',
                ...activeSelections.map((selection) => selection.countryCode!),
              ],
              headerStyle: pw.TextStyle(
                font: boldFont,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              data: tableData,
            ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'passport_diff_report.pdf',
    );
  }

  // 在 initState 中自動載入舊紀錄
  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadFavorites(); // 初始化時從本地端讀取
  }

  List<FavoriteSnapshot> _decodeFavorites(String payload) {
    try {
      final decoded = json.decode(payload);
      if (decoded is! List) {
        _logWarn("Invalid favorites payload: root is not a list");
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (item) =>
                FavoriteSnapshot.fromJson(item, fallbackYear: currentYear),
          )
          .toList();
    } catch (e, stackTrace) {
      _logWarn(
        "Failed to parse favorites payload",
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // 載入資料 (Read)
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favString = prefs.getString('favorites_list');
    if (favString != null) {
      setState(() {
        _favorites = _decodeFavorites(favString);
      });
      _logInfo("Loaded ${_favorites.length} favorites from disk.");
    }
  }

  // 儲存資料 (Save)
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String favString = json.encode(
      _favorites.map((favorite) => favorite.toJson()).toList(),
    );
    await prefs.setString('favorites_list', favString);
  }

  void _onRemoveFavorite(int index) {
    setState(() {
      _favorites.removeAt(index);
    });
    _saveFavorites(); // 刪除後更新本地端
  }

  Future<void> _loadFavoriteToHome(FavoriteSnapshot item) async {
    setState(() {
      _session = ComparisonSession.fromFavoriteSnapshot(item);
      isComparing = true;
      showDetails = true;
      _selectedIndex = 0;
    });

    for (final code in item.activeCodes) {
      if (!visaFreeMap.containsKey(code)) {
        final detailCodes = await _apiService.fetchVisaFreeCodes(code);
        setState(() {
          visaFreeMap[code] = detailCodes;
        });
      }
    }
  }

  Future<void> _onReset() async {
    // 顯示確認對話框
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Reset Comparison"),
          ],
        ),
        content: const Text(
          "This will clear all current selections and results. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset Now"),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;

    setState(() {
      _session = ComparisonSession.empty(defaultYear: currentYear);
      isComparing = false;
      showDetails = false;
      visaFreeMap.clear();
      hasInitialized = false; // 回到 Start 畫面
    });
    _logWarn("User confirmed state reset.");
  }

  Future<String?> _showRenameDialog(String initialTitle) async {
    TextEditingController controller = TextEditingController(
      text: initialTitle,
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save to Favorites"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter a name for this comparison:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Comparison Title",
                hintText: "e.g. My Summer Trip",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 傳回 null
            child: const Text("Cancel"),
          ),
          FilledButton(
            key: saveFavoriteDialogButtonKey,
            onPressed: () => Navigator.pop(context, controller.text), // 傳回輸入內容
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddToFavorite() async {
    // 防呆：如果還沒按下 Compare 或沒有選中任何國家，則不執行
    if (!isComparing || !_session.hasAnySelected) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select countries and compare first!"),
        ),
      );
      return;
    }
    try {
      final names = _activeSelections
          .map(
            (selection) => allCountries
                .firstWhere((c) => c.code == selection.countryCode)
                .name,
          )
          .toList();
      final defaultTitle = names.join(' vs ');
      final customTitle = await _showRenameDialog(defaultTitle);

      if (!mounted || customTitle == null) return; // 2. 建立一筆新的最愛紀錄

      setState(() {
        _favorites.add(
          _session.toFavoriteSnapshot(
            title: customTitle,
            date: DateTime.now().toString().substring(0, 16),
          ),
        );
      });
      await _saveFavorites();

      // --- 再次檢查，因為上面又有一個 await ---
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved as '$customTitle'"),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      _logError("Failed to add favorite");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error adding to favorites.")),
      );
    }
  }

  // 1. 核心邏輯：使用者點擊開始後才呼叫 /countries API
  Future<void> _onStartComparing() async {
    setState(() => isLoadingInitial = true);
    final data = await _apiService.fetchCountries();
    setState(() {
      allCountries = data;
      hasInitialized = true;
      isLoadingInitial = false;
    });
  }

  // 2. 核心邏輯：按下 Details 後獲取所有選中護照的 /visa-single 數據
  Future<void> _onShowDetails() async {
    // 1. 檢查是否有任何選中的國家代碼
    final activeCodes = _session.activeCodes;

    if (activeCodes.isEmpty) return;

    // 2. 檢查是否所有選中的國家都已經在快取 (visaFreeMap) 中
    bool allCached = activeCodes.every((code) => visaFreeMap.containsKey(code));

    if (allCached) {
      // 如果資料都已經有了，直接顯示 UI，不進入 Loading 狀態
      setState(() => showDetails = true);
      return;
    }

    setState(() {
      isLoadingDetails = true;
      showDetails = true;
    });

    for (String code in activeCodes) {
      // Lazy Loading 核心：只抓取 Map 裡沒有的 code
      if (!visaFreeMap.containsKey(code)) {
        try {
          final codes = await _apiService.fetchVisaFreeCodes(code);
          visaFreeMap[code] = codes;
        } catch (e, stackTrace) {
          _logError(
            "Failed to fetch visa details",
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    }
    setState(() => isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "Passport Comparison" : "My Favorites",
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
            ),
            tooltip: "switch modes",
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1D2A2E), Color(0xFF152124)]
                      : const [Color(0xFF7B392A), Color(0xFFA6533D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  "Passport Index\nToolbox",
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFEFE7DA)
                        : const Color(0xFFFDF5EA),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              key: favoritesDrawerTileKey,
              leading: const Icon(Icons.favorite),
              title: const Text("Favorites"),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _selectedIndex == 0 ? _buildHomePage() : _buildFavoritesPage(),
      ),
    );
  }

  Widget _buildHomePage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Screenshot(
      controller: _screenshotController,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF13191C), Color(0xFF1A2226)]
                : const [Color(0xFFF4E9DD), Color(0xFFEEDFD0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF25343A), Color(0xFF1E2A2F)]
                        : const [Color(0xFF8D4430), Color(0xFFB35A40)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Passport Atlas",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFFF9F3E8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Model mobility strength, compare access patterns, and export shareable reports.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFF5ECE1).withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "How many passports to compare today? (Max 5)",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {passportCount},
                onSelectionChanged: !hasInitialized
                    ? (Set<int> newSelection) {
                        setState(() {
                          _session = _session.updatePassportCount(
                            newSelection.first,
                          );
                        });
                      }
                    : null,
                style: ButtonStyle(
                  visualDensity: VisualDensity.comfortable,
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFFD46B54).withValues(alpha: 0.2);
                    }
                    return null;
                  }),
                ),
              ),
              const SizedBox(height: 10),
              if (!hasInitialized)
                FilledButton.tonal(
                  key: startButtonKey,
                  onPressed: isLoadingInitial ? null : _onStartComparing,
                  child: isLoadingInitial
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Start"),
                ),
              if (hasInitialized) ...[
                const SizedBox(height: 12),
                const Divider(height: 20),
                ...List.generate(
                  passportCount,
                  (i) => PassportInputRow(
                    index: i,
                    countries: allCountries,
                    selectedCode: _session.selections[i].countryCode,
                    selectedYear: _session.selections[i].year,
                    onCountryChanged: (val) {
                      setState(() {
                        _session = _session.updateCountry(i, val);
                        showDetails = false;
                      });
                    },
                    onYearChanged: (val) {
                      setState(() {
                        _session = _session.updateYear(i, val!);
                        showDetails = false;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      key: compareButtonKey,
                      onPressed: _session.hasAllSelected
                          ? () => setState(() => isComparing = true)
                          : null,
                      child: const Text("Compare"),
                    ),
                    ElevatedButton(
                      key: detailsButtonKey,
                      onPressed: isComparing ? _onShowDetails : null,
                      child: const Text("Details"),
                    ),
                    IconButton.filledTonal(
                      key: addFavoriteButtonKey,
                      onPressed: isComparing ? _onAddToFavorite : null,
                      icon: const Icon(Icons.favorite_border),
                      tooltip: "Add to Favorite",
                    ),
                    IconButton.filledTonal(
                      key: resetAllButtonKey,
                      onPressed: _onReset,
                      icon: const Icon(Icons.restart_alt),
                      tooltip: "Reset All",
                    ),
                    IconButton(
                      key: shareScreenshotButtonKey,
                      onPressed: isComparing
                          ? () => _shareScreenshot(_screenshotController)
                          : null,
                      icon: const Icon(Icons.share_outlined),
                      tooltip: "Share Screenshot",
                    ),
                    IconButton(
                      key: exportFullPdfButtonKey,
                      onPressed: isComparing
                          ? () => _exportToPdf(diffOnly: false)
                          : null,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: "Export Full PDF",
                    ),
                    IconButton.filledTonal(
                      key: exportDiffPdfButtonKey,
                      onPressed: isComparing
                          ? () => _exportToPdf(diffOnly: true)
                          : null,
                      icon: const Icon(Icons.difference_outlined),
                      tooltip: "Export Differences Only PDF",
                    ),
                  ],
                ),
              ],
              if (isComparing) ...[
                const SizedBox(height: 22),
                _buildSummaryResults(),
              ],
              if (showDetails) ...[
                const SizedBox(height: 34),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Detailed Access Comparison",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesPage() {
    final theme = Theme.of(context);
    if (_favorites.isEmpty) {
      return Center(
        child: Text(
          "No favorites added yet.",
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final item = _favorites[index];
        final title = item.title;
        final date = item.date;
        final activeCodes = item.activeCodes;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.folder_shared_outlined),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              "Saved on: $date",
              style: const TextStyle(fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _onRemoveFavorite(index),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(),
                child: Column(
                  children: [
                    const Text(
                      "Quick Summary",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFavoriteSummaryPreview(context, item, allCountries),
                    const Divider(height: 30),
                    const Text(
                      "Detailed Access",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ComparisonTable(
                      selectedCodes: activeCodes,
                      allCountries: allCountries,
                      visaFreeMap: visaFreeMap,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _loadFavoriteToHome(item),
                      icon: const Icon(Icons.edit_note),
                      label: const Text("Load into Editor"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryResults() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(passportCount, (i) {
          final selection = _session.selections[i];
          final code = selection.countryCode;
          if (code == null) {
            return const Expanded(
              child: Center(child: Text("Select Passport")),
            );
          }

          final country = allCountries.firstWhere((c) => c.code == code);
          final selectedYear = selection.year;
          final Map<String, dynamic>? dataMap = country.yearlyData;
          final yearData = (country.hasData && dataMap != null)
              ? dataMap[selectedYear]
              : null;

          return Expanded(
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(4),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 45,
                    height: 32,
                    child: (code.isEmpty)
                        ? const Icon(Icons.flag, size: 24, color: Colors.grey)
                        : CountryFlag.fromCountryCode(code.toUpperCase()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  country.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    country.region,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ),

                const Divider(),
                if (country.hasData && yearData != null) ...[
                  Text(
                    "Year: $selectedYear",
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Rank: ${yearData['rank']}",
                    style: const TextStyle(
                      color: Color(0xFFB34A32),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Visa Free: ${yearData['visa_free_count']}",
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  OpennessIndicator(score: country.openness, height: 4),
                ] else ...[
                  // 當無數據時顯示的視覺標籤
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "No Data\nAvailable",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5D6A6E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailsSection() {
    if (isLoadingDetails) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return ComparisonTable(
      selectedCodes: _session.activeCodes,
      allCountries: allCountries,
      visaFreeMap: visaFreeMap,
    );
  }
}

Widget _buildFavoriteSummaryPreview(
  BuildContext context,
  FavoriteSnapshot item,
  List<Country> allCountries,
) {
  final theme = Theme.of(context);
  final activeSelections = item.selections
      .take(item.count)
      .where(
        (selection) =>
            selection.countryCode != null && selection.countryCode!.isNotEmpty,
      );

  if (activeSelections.isEmpty) return const SizedBox.shrink(); // 如果沒資料就隱藏

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: activeSelections.map((selection) {
      final displayCode = selection.countryCode!.trim().toUpperCase();
      Country? country;
      try {
        country = allCountries.firstWhere((c) => c.code == displayCode);
      } catch (_) {
        country = null;
      }
      final year = selection.year;
      final yearDataMap = country?.yearlyData;
      final yearStats = (country?.hasData ?? false) && yearDataMap != null
          ? yearDataMap[year]
          : null;

      return Column(
        children: [
          CountryFlag.fromCountryCode(displayCode),
          const SizedBox(height: 4),
          Text(
            country?.name ?? displayCode,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            "Region: ${country?.region ?? 'N/A'}",
            style: theme.textTheme.labelSmall,
          ),
          Text(
            "Rank: ${yearStats?['rank'] ?? 'N/A'}",
            style: theme.textTheme.labelSmall,
          ),
          Text(
            "Visa-Free: ${yearStats?['visa_free_count'] ?? 'N/A'}",
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF2E7D5A),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            "Year: $year",
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }).toList(),
  );
}
