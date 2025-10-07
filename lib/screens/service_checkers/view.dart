import 'package:flutter/material.dart';

class ViewServiceCheckerScreen extends StatelessWidget {
  final Map<String, dynamic> checkerData;
  const ViewServiceCheckerScreen({super.key, required this.checkerData});

  @override
  Widget build(BuildContext context) {
    final items = checkerData['items'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(checkerData['title']),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Date", checkerData['date']),
            _buildInfoRow("Driver", checkerData['driver']['name']),
            _buildInfoRow("Created By", "${checkerData['createdBy']['username']}"),
            const SizedBox(height: 20),
            const Text("Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...items.map((item) => _buildItemCard(item)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final notes = item['notes'] as List<dynamic>? ?? [];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        children: notes.map((note) => ListTile(
          leading: const Icon(Icons.note, color: Colors.blueAccent),
          title: Text(note['note']),
        )).toList(),
      ),
    );
  }
}
