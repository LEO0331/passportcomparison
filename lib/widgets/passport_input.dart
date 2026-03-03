import 'package:flutter/material.dart';
import '../models/country.dart';

class PassportInputRow extends StatelessWidget {
  final int index;
  final List<Country> countries;
  final String? selectedCode;
  final String selectedYear;
  final Function(String?) onCountryChanged;
  final Function(String?) onYearChanged;

  const PassportInputRow({
    super.key,
    required this.index,
    required this.countries,
    this.selectedCode,
    required this.selectedYear,
    required this.onCountryChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text("Passport ${index + 1}"),
              value: selectedCode,
              items: countries
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onCountryChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedYear,
              items: List.generate(
                21,
                (i) => (2006 + i).toString(),
              ).map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: onYearChanged,
            ),
          ),
        ],
      ),
    );
  }
}
