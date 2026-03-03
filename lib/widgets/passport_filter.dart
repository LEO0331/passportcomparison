import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:passportcomparison/widgets/openness_indicator.dart';
import '../models/country.dart';

class PassportFilter extends StatefulWidget {
  final List<Country> allCountries;
  final String? selectedCode;
  final String selectedYear;
  final Function(String?) onCountryChanged;
  final Function(String?) onYearChanged;

  const PassportFilter({
    super.key,
    required this.allCountries,
    required this.selectedCode,
    required this.selectedYear,
    required this.onCountryChanged,
    required this.onYearChanged,
  });

  @override
  State<PassportFilter> createState() => _PassportFilterState();
}

class _PassportFilterState extends State<PassportFilter> {
  String _selectedRegion = "All";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // 取得當前選中的國家物件，用於顯示 Openness
    final Country? currentCountry = widget.selectedCode != null
        ? widget.allCountries.firstWhere((c) => c.code == widget.selectedCode)
        : null;

    final List<String> regions = ["All", ...widget.allCountries.map((e) => e.region).toSet()];

    final List<Country> filteredCountries = _selectedRegion == "All"
        ? widget.allCountries
        : widget.allCountries.where((c) => c.region == _selectedRegion).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一列：區域、年份與 Openness 分數顯示
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRegion,
                  decoration: const InputDecoration(labelText: "Region", border: OutlineInputBorder()),
                  items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (reg) => setState(() => _selectedRegion = reg!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: widget.selectedYear,
                  decoration: const InputDecoration(labelText: "Year", border: OutlineInputBorder()),
                  items: ["2024", "2023", "2022"].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: widget.onYearChanged,
                ),
              ),
              // 視覺反饋：Openness 分數
              if (currentCountry != null)
                Expanded(
                  flex: 2,
                  child: OpennessIndicator(score: currentCountry.openness),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 第二列：具備搜尋功能的國家下拉選單
          DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: const Text("Search and Select Country"),
              items: filteredCountries.map((c) => DropdownMenuItem<String>(
                value: c.code,
                child: Text(c.name),
              )).toList(),
              value: widget.selectedCode,
              onChanged: widget.onCountryChanged,
              buttonStyleData: ButtonStyleData(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
              dropdownStyleData: const DropdownStyleData(maxHeight: 300),
              // 搜尋框設定
              dropdownSearchData: DropdownSearchData(
                searchController: _searchController,
                searchInnerWidgetHeight: 50,
                searchInnerWidget: Container(
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  child: TextFormField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      hintText: 'Search country name...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    ),
                  ),
                ),
                searchMatchFn: (item, searchValue) {
                  // 根據顯示的國家名稱進行搜尋比對
                  final country = filteredCountries.firstWhere((c) => c.code == item.value);
                  return country.name.toLowerCase().contains(searchValue.toLowerCase());
                },
              ),
              onMenuStateChange: (isOpen) {
                if (!isOpen) _searchController.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
