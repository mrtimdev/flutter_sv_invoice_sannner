import 'package:flutter/material.dart';
import 'package:sv_service_checker/enum/dateFilter.dart';
import 'package:sv_service_checker/providers/service_checker_provider.dart';

class DateFilterBar extends StatelessWidget {
  final DateFilter currentFilter;
  final ValueChanged<DateFilter> onFilterChange;
  final String? selectedDriverId;
  final List<dynamic> drivers;
  final ValueChanged<String?> onDriverChange;

  const DateFilterBar({
    Key? key,
    required this.currentFilter,
    required this.onFilterChange,
    this.selectedDriverId,
    required this.drivers,
    required this.onDriverChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Driver filter
          Row(
            children: [
              Text(
                'Driver: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedDriverId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Drivers'),
                    ),
                    ...drivers.map<DropdownMenuItem<String>>((driver) {
                      return DropdownMenuItem<String>(
                        value: driver['id'].toString(),
                        child: Text('${driver['firstName']} ${driver['lastName']}'),
                      );
                    }).toList(),
                  ],
                  onChanged: onDriverChange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Date filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DateFilter.values.map((filter) {
              return FilterChip(
                label: Text(getDateFilterText(filter)),
                selected: currentFilter == filter,
                onSelected: (selected) {
                  if (selected) {
                    onFilterChange(filter);
                  }
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.blue[200],
                labelStyle: TextStyle(
                  color: currentFilter == filter ? Colors.blue[800] : Colors.grey[800],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}