import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:passportcomparison/widgets/openness_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/country.dart';
import 'services/api_service.dart';
import 'widgets/passport_input.dart';
import 'widgets/comparison_table.dart';
import 'package:country_flags/country_flags.dart';
import 'package:logger/logger.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
void main() {
  runApp(MaterialApp(
    home: PassportComparePage(),
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.system,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blueGrey,
    ),
  ));
}

class PassportComparePage extends StatefulWidget {
  const PassportComparePage({super.key});

  @override
  State<PassportComparePage> createState() => _PassportComparePageState();
}

class _PassportComparePageState extends State<PassportComparePage> {
  final ApiService _apiService = ApiService();
  final _logger = Logger();
  static final String currentYear = DateTime.now().year.toString();
  final ScreenshotController _screenshotController = ScreenshotController();
  // 狀態變數
  int passportCount = 2; 
  List<Country> allCountries = []; 
  bool hasInitialized = false; // 控制是否已抓取國家清單
  bool isLoadingInitial = false;
  bool isComparing = false;
  bool showDetails = false;
  bool isLoadingDetails = false;
  int _selectedIndex = 0; // 0: Home, 1: Favorites
  List<Map<String, dynamic>> _favorites = []; // 儲存我的最愛清單
  List<String?> selectedCountryCodes = List.filled(5, null);
  List<String> selectedYears = List.filled(5, currentYear);   

  Map<String, Set<String>> visaFreeMap = {};

  // --- 分享截圖 ---
  Future<void> _shareScreenshot(ScreenshotController controller) async {
    try {
      final image = await controller.capture();
      if (image == null) return;
      if (kIsWeb) {
        // 在 Web 端，'share_plus' 的圖片分享有限制
        // 建議直接使用 'printing' 套件的分享功能，它在 Web 表現最穩
        await Printing.sharePdf(
          bytes: image, 
          filename: 'passport_comparison.png'
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/passport_comparison.png').create();
        await file.writeAsBytes(image);
        await Share.shareXFiles([XFile(file.path)], text: 'Passport Comparison');
      }
    } catch (e) {
      _logger.e("Share error: $e");
    }
  }
  // --- 導出 PDF ---
  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text("Passport Comparison Report", style: pw.TextStyle(fontSize: 24)),
          // 這裡可以根據資料生成 PDF 表格，或將截圖放入 PDF
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
// 在 initState 中自動載入舊紀錄
@override
void initState() {
  super.initState();
  _loadFavorites(); // 初始化時從本地端讀取
}

// 載入資料 (Read)
Future<void> _loadFavorites() async {
  final prefs = await SharedPreferences.getInstance();
  final String? favString = prefs.getString('favorites_list');
  if (favString != null) {
    setState(() {
      _favorites = List<Map<String, dynamic>>.from(json.decode(favString));
    });
    _logger.i("Loaded ${_favorites.length} favorites from disk.");
  }
}

// 儲存資料 (Save)
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String favString = json.encode(_favorites);
    await prefs.setString('favorites_list', favString);
  }

  void _onRemoveFavorite(int index) {
    setState(() {
      _favorites.removeAt(index);
    });
    _saveFavorites(); // 刪除後更新本地端
  }
  
  Future<void> _loadFavoriteToHome(Map<String, dynamic> item) async {
    setState(() {
      selectedCountryCodes = List<String?>.from(item['codes'])..addAll(List.filled(5 - (item['codes'] as List).length, null));
      selectedYears = List<String>.from(item['years'])..addAll(List.filled(5 - (item['years'] as List).length, currentYear));
      passportCount = item['count'] ?? 1;
      isComparing = true;
      showDetails = true; 
      _selectedIndex = 0; 
    });

    List<String> codes = List<String>.from(item['codes']);
    for (var code in codes) {
      if (!visaFreeMap.containsKey(code)) {
        var detailCodes = await _apiService.fetchVisaFreeCodes(code);
        setState(() {
          // 假設你的全域變數 visaFreeMap 結構是 Map<String, Set<String>>
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
      content: const Text("This will clear all current selections and results. Are you sure?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), 
          child: const Text("Cancel")
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
          onPressed: () => Navigator.pop(context, true), 
          child: const Text("Reset Now")
        ),
      ],
    ),
  );
  if (!mounted || confirm != true) return;
  
    setState(() {
      selectedCountryCodes = List.filled(5, null);
      selectedYears = List.filled(5, currentYear);
      isComparing = false;
      showDetails = false;
      visaFreeMap.clear();
      passportCount = 2;
      hasInitialized = false; // 回到 Start 畫面
    });
    _logger.w("User confirmed state reset.");
  
}

Future<String?> _showRenameDialog(String initialTitle) async {
  TextEditingController controller = TextEditingController(text: initialTitle);

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Save to Favorites"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Enter a name for this comparison:", style: TextStyle(fontSize: 14)),
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
          onPressed: () => Navigator.pop(context, controller.text), // 傳回輸入內容
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

Future<void> _onAddToFavorite() async {
  // 防呆：如果還沒按下 Compare 或沒有選中任何國家，則不執行
  if (!isComparing || selectedCountryCodes.where((c) => c != null).isEmpty) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select countries and compare first!")),
    );
    return;
  }
  final activeCodes = selectedCountryCodes.take(passportCount).whereType<String>().toList();
  try {
    List<String> names = selectedCountryCodes
      .take(passportCount)
      .map((code) => allCountries.firstWhere((c) => c.code == code).name)
      .toList();
    String defaultTitle = names.join(' vs ');
    String? customTitle = await _showRenameDialog(defaultTitle);

    if (!mounted || customTitle == null) return;    // 2. 建立一筆新的最愛紀錄

    List<Map<String, dynamic>> summaryData = [];
    for (int i = 0; i < activeCodes.length; i++) {
      String code = activeCodes[i];
      String year = selectedYears[i];
      
      // 從 allCountries 找到該國家的模型
      Country country = allCountries.firstWhere((c) => c.code == code);
      
      // yearlyData 是一個 Map<String, dynamic>
      var yearStats = country.yearlyData?[year]; 

      summaryData.add({
        'code': code,
        'name': country.name,
        'region': country.region,
        'year': year,
        'rank': yearStats?['rank']?.toString() ?? "N/A",
        'visaFree': yearStats?['visa_free_count']?.toString() ?? "0",
      });
    }

    setState(() {
    _favorites.add({
      'title': names.join(' vs '),
      'date': DateTime.now().toString().substring(0, 16),
      'codes': List.from(selectedCountryCodes),
      'years': List.from(selectedYears),
      'count': passportCount,
      'summary': summaryData, // 存入這筆收藏的完整快照
    });
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
    _logger.e("Failed to add favorite: $e");
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
    final activeCodes = selectedCountryCodes.take(passportCount).whereType<String>().toList();
    
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
            _logger.e("Failed to fetch", error: e, stackTrace: stackTrace);
          }
        }
      }
    setState(() => isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(_selectedIndex == 0 ? "Passport Comparison" : "My Favorites"),
          backgroundColor: const Color(0xFF455A64),
          foregroundColor: Colors.white,
        ),   
        drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF455A64)),
              child: Center(
                child: Text("Passport Index\nToolbox",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
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
      body: _selectedIndex == 0 ? _buildHomePage() : _buildFavoritesPage(),
   );
  }

  Widget _buildHomePage() {
    return Screenshot(
      controller: _screenshotController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        
        child: Column(
          children: [
            // 步驟 1: 選擇人數
            const Text("How many passports to compare today? (Max 5)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            
            SizedBox(height: 5),
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
                      setState(() => passportCount = newSelection.first);
                    } 
                  : null,
                  style: const ButtonStyle(visualDensity: VisualDensity.comfortable,),
            ),
            // 步驟 2: 點擊開始抓取 API
            SizedBox(height: 5),
            if (!hasInitialized)
              Center(
                child: ElevatedButton(
                  onPressed: isLoadingInitial ? null : _onStartComparing,
                  child: isLoadingInitial 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Start"),
                ),
              ),

            // 步驟 3: 顯示輸入列
            if (hasInitialized) ...[
              const Divider(height: 30),
              ...List.generate(passportCount, (i) => PassportInputRow(
                index: i,
                countries: allCountries,
                selectedCode: selectedCountryCodes[i],
                selectedYear: selectedYears[i],
                onCountryChanged: (val) {
                  setState(() {
                    selectedCountryCodes[i] = val;
                    showDetails = false; // 國家一變，就強制關閉詳情，要求用戶手動再按一次
                  });
                },                
                onYearChanged: (val) {
                  setState(() {
                    selectedYears[i] = val!;
                    showDetails = false;
                  });
                } 
              )),
              
              const SizedBox(height: 20),
              // 按鈕列
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: selectedCountryCodes.take(passportCount).contains(null) 
                      ? null 
                      : () => setState(() => isComparing = true), 
                    child: const Text("Compare")
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isComparing ? _onShowDetails : null, 
                    child: const Text("Details")
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: isComparing ? _onAddToFavorite : null,
                    icon: const Icon(Icons.favorite_border),
                    style: IconButton.styleFrom(backgroundColor: Colors.pink.shade300),
                    tooltip: "Add to Favorite",
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _onReset,
                    icon: const Icon(Icons.restart_alt),
                    style: IconButton.styleFrom(backgroundColor: Colors.orange.shade400),
                    tooltip: "Reset All",
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: isComparing ? () => _shareScreenshot(_screenshotController) : null,
                    icon: const Icon(Icons.share_outlined),
                    tooltip: "Share Screenshot",
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: showDetails ? _exportToPdf : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: "Export PDF",
                  ),
                ],
              ),
            ],

            // 步驟 4: 顯示摘要結果 (Rank, Visa Free Count)
            if (isComparing) ...[
              const SizedBox(height: 20),
              _buildSummaryResults(),
            ],
            // 步驟 5: 顯示詳細比對表 (打勾/打叉清單)
            if (showDetails) ...[
              const SizedBox(height: 40), 
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Detailed Access Comparison", 
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailsSection(),
            ],
          ],
        ),
      
    )
  );
  }

  Widget _buildFavoritesPage() {
  if (_favorites.isEmpty) {
    return const Center(child: Text("No favorites added yet."));
  }

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _favorites.length,
    itemBuilder: (context, index) {
      final item = _favorites[index];
      final String title = (item['title']?.toString()) ?? "Untitled Comparison";
      final String date = (item['date']?.toString()) ?? "Unknown Date";
      final List<String> activeCodes = (item['codes'] as List?)
              ?.map((e) => e?.toString() ?? "")
              .where((e) => e.isNotEmpty)
              .toList() ?? [];

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.folder_shared_outlined),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Saved on: $date", style: const TextStyle(fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _onRemoveFavorite(index),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(),
              child: Column(
                children: [
                  const Text("Quick Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 10),
                  // 1. 這裡放置縮小版的摘要組件 (Reuse 你的 _buildSummaryResults 邏輯)
                  _buildFavoriteSummaryPreview(item),
                  const Divider(height: 30),
                  const Text("Detailed Access", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 10),
                  // 2. 直接顯示詳細表
                  ComparisonTable(
                    selectedCodes: activeCodes,
                    allCountries: allCountries,
                    visaFreeMap: visaFreeMap,
                  ),
                  const SizedBox(height: 12),
                  // 3. 恢復到首頁繼續編輯按鈕
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
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 166, 186, 196).withValues(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(passportCount, (i) {
          final code = selectedCountryCodes[i];
          if (code == null) return const Expanded(child: Center(child: Text("Select Passport")));

          final country = allCountries.firstWhere((c) => c.code == code);
          final selectedYear = selectedYears[i];
          final Map<String, dynamic>? dataMap = country.yearlyData;
          final yearData = (country.hasData && dataMap != null) ? dataMap[selectedYear] : null;

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
                    : CountryFlag.fromCountryCode(
                        code.toUpperCase(),
                      ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(country.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: Text(country.region, style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                ),

                const Divider(),
                if (country.hasData && yearData != null) ...[
                  Text("Year: $selectedYear", style: const TextStyle(fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(
                    "Rank: ${yearData['rank']}", 
                    style: const TextStyle(color: Color.fromARGB(255, 149, 62, 80), fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                  Text("Visa Free: ${yearData['visa_free_count']}", style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 12),
                  OpennessIndicator(score: country.openness, height: 4),
                ] else ...[
                  // 當無數據時顯示的視覺標籤
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off, size: 18, color: Colors.grey.shade700),
                        const SizedBox(height: 4),
                        const Text(
                          "No Data\nAvailable", 
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: Color(0xFF455A64), fontWeight: FontWeight.w500)
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
        child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())
      );
    }
    return ComparisonTable(
      selectedCodes: selectedCountryCodes.take(passportCount).whereType<String>().toList(),
      allCountries: allCountries,
      visaFreeMap: visaFreeMap,
    );
  }
}

Widget _buildFavoriteSummaryPreview(Map<String, dynamic> item) {
  // final List<String> codes = (item['codes'] as List)
  //     .where((e) => e != null) // 關鍵：過濾掉 null
  //     .map((e) => e.toString())
  //     .toList();
final List<Map<String, dynamic>> codes = (item['summary'] as List? ?? [])
      .where((e) => e != null) // 過濾掉 null 元素
      .cast<Map<String, dynamic>>() // 強制轉型為需要的 Map 格式
      .toList();

  if (codes.isEmpty) return const SizedBox.shrink(); // 如果沒資料就隱藏

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: codes.map((code) {
      final String rawCode = code['code']?.toString() ?? "";
      final String displayCode = rawCode.trim().toUpperCase();
      return Column(
        children: [
          //CountryFlag.fromCountryCode(code.toUpperCase()),
          CountryFlag.fromCountryCode(displayCode),
          const SizedBox(height: 4),
          //Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text(code['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text("Region: ${code['region']}", style: const TextStyle(fontSize: 9)),
          Text("Rank: ${code['rank']}", style: const TextStyle(fontSize: 9)),
          Text("Visa-Free: ${code['visaFree']}", style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
          Text("Year: ${code['year']}", style: const TextStyle(fontSize: 8, color: Colors.grey)),

        ],
      );
    }).toList(),
  );
}
