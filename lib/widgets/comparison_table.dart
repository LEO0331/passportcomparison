import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:screenshot/screenshot.dart';
import '../models/country.dart';

class ComparisonTable extends StatefulWidget {
  final List<String> selectedCodes; // 已選中的國家代碼
  final List<Country> allCountries; // 所有國家數據
  final Map<String, Set<String>> visaFreeMap; // 簽證狀態快取
  final ScreenshotController? screenshotController; // 選填，由外部傳入以支援截圖

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
  String _searchQuery = ""; // 目的地搜尋文字
  bool _showDifferencesOnly = false; // 是否僅顯示差異

  @override
  Widget build(BuildContext context) {
    // 1. 取得目前參與比對的護照國家實例
    final activePassports = widget.selectedCodes
        .map((code) => widget.allCountries.firstWhere((c) => c.code == code))
        .toList();

    // 2. 處理過濾邏輯
    Iterable<Country> filtered = widget.allCountries.where(
      (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
    );

    // 如果開啟「僅顯示差異」，且比對對象超過一個
    if (_showDifferencesOnly && activePassports.length > 1) {
      filtered = filtered.where((target) {
        final statuses = activePassports.map((p) {
          // 檢查該目的地是否在該護照的免簽清單中
          return (p.code == target.code) ||
              (widget.visaFreeMap[p.code]?.contains(target.code) ?? false);
        }).toSet();
        return statuses.length > 1; // 如果 Set 長度 > 1，代表結果有異
      });
    }

    final filteredDestinations = filtered.toList();

    // 3. 建立表格佈局
    Widget tableContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- 頂部工具列：搜尋 + 差異開關 ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search destination...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("Diff Only", style: TextStyle(fontSize: 11)),
                selected: _showDifferencesOnly,
                onSelected: (val) => setState(() => _showDifferencesOnly = val),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),

        // --- 固定表頭表格 ---
        StickyHeader(
          header: _buildStickyHeader(activePassports),
          content: Container(
            color: Theme.of(context).cardColor,
            child: Table(
              border: TableBorder.all(color: Colors.grey.withValues()),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: FlexColumnWidth(2.5)},
              children: filteredDestinations.map((target) {
                return TableRow(
                  children: [
                    // 目的地國家名稱
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        target.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    // 各護照對應的准入狀態
                    ...activePassports.map((passport) {
                      return _buildStatusCell(passport, target);
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );

    // 如果有傳入截圖控制器，則包裹 Screenshot 組件
    if (widget.screenshotController != null) {
      return Screenshot(
        controller: widget.screenshotController!,
        child: tableContent,
      );
    }

    return tableContent;
  }

  // 構建固定在頂部的表頭
  Widget _buildStickyHeader(List<Country> passports) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // 確保背景不透明
      child: Table(
        border: TableBorder.all(color: Colors.grey.withValues()),
        columnWidths: const {0: FlexColumnWidth(2.5)},
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.blueGrey.withValues()),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                  "Destination",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              ...passports.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryFlag.fromCountryCode(p.code.toUpperCase()),
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
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

  // 構建個別單元格的狀態 (勾選、叉號、或是 Home/Free)
  Widget _buildStatusCell(Country passport, Country target) {
    // 1. 特殊邏輯：如果是該護照持有國 (目的地 = 護照國)
    // if (passport.code == target.code) {
    //   return Container(
    //     height: 40,
    //     color: Colors.blue.withValues(),
    //     alignment: Alignment.center,
    //     child: const Text("Home",
    //       style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
    //   );
    // }

    // 2. 處理無數據情況
    if (!passport.hasData) {
      return Container(
        height: 40,
        color: Colors.grey.withValues(),
        alignment: Alignment.center,
        child: const Text(
          "N/A",
          style: TextStyle(color: Colors.grey, fontSize: 10),
        ),
      );
    }

    // 3. 正常簽證狀態判斷
    bool isFree =
        (passport.code == target.code) ||
        (widget.visaFreeMap[passport.code]?.contains(target.code) ?? false);
    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Icon(
        isFree ? Icons.check_circle : Icons.cancel_outlined,
        color: isFree ? Colors.green : Colors.red.withValues(),
        size: 18,
      ),
    );
  }
}
