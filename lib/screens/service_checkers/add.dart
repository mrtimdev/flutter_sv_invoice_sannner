import 'package:flutter/material.dart';

import '../../services/service_check_service.dart';

class AddServiceCheckerScreen extends StatefulWidget {
  const AddServiceCheckerScreen({super.key});

  @override
  State<AddServiceCheckerScreen> createState() => _AddServiceCheckerScreenState();
}

class _AddServiceCheckerScreenState extends State<AddServiceCheckerScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _title;
  DateTime? _date;
  int? _driverId;

  List<Map<String, dynamic>> _items = [];

  List<dynamic> _drivers = [];

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    try {
      final data = await ServiceCheckService.getDrivers();
      setState(() {
        _drivers = data;
      });
    } catch (e) {
      debugPrint("Error loading drivers: $e");
    }
  }

  void _addItem() {
    setState(() {
      _items.add({"title": "", "notes": []});
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addNoteToItem(int itemIndex) {
    setState(() {
      _items[itemIndex]["notes"].add({"note": ""});
    });
  }

  void _removeNoteFromItem(int itemIndex, int noteIndex) {
    setState(() {
      _items[itemIndex]["notes"].removeAt(noteIndex);
    });
  }

  Future<void> _saveChecker() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final payload = {
      "title": _title,
      "date": _date?.toIso8601String().split("T")[0],
      "driver": {"id": _driverId},
      "items": _items
    };

    try {
      await ServiceCheckService.createServiceChecker(payload);
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving checker: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save service checker")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Service Checker")),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) => v!.isEmpty ? "Title required" : null,
                onSaved: (v) => _title = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _driverId,
                decoration: const InputDecoration(labelText: "Driver"),
                items: _drivers
                    .map((d) => DropdownMenuItem<int>(
                          value: d['id'],
                          child: Text("${d['firstName']} - ${d['lastName']}"),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _driverId = v),
                validator: (v) => v == null ? "Driver required" : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(_date == null
                        ? "No date selected"
                        : "Date: ${_date!.toLocal().toString().split(' ')[0]}"),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                    child: const Text("Pick Date"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Items", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Column(
                children: _items.asMap().entries.map((entry) {
                  int itemIndex = entry.key;
                  var item = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: item["title"],
                            decoration: const InputDecoration(labelText: "Item Title"),
                            onChanged: (v) => _items[itemIndex]["title"] = v,
                          ),
                          const SizedBox(height: 5),
                          Column(
                            children: (item["notes"] as List).asMap().entries.map((noteEntry) {
                              int noteIndex = noteEntry.key;
                              return Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: noteEntry.value["note"],
                                      decoration: const InputDecoration(labelText: "Note"),
                                      onChanged: (v) => _items[itemIndex]["notes"][noteIndex]["note"] = v,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeNoteFromItem(itemIndex, noteIndex),
                                  )
                                ],
                              );
                            }).toList(),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _addNoteToItem(itemIndex),
                              icon: const Icon(Icons.add),
                              label: const Text("Add Note"),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _removeItem(itemIndex),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text("Remove Item"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text("Add Item"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChecker,
                child: const Text("Save"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
