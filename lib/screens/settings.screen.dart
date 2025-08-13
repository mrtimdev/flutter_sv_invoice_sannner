import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sv_service_checker/providers/settings.provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    provider.fetchSettings().then((_) {
      _descController.text = provider.description;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Auto Cropping'),
                  value: provider.isScanWithAi,
                  onChanged: (val) {
                    provider.isScanWithAi = val;
                  },
                ),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (val) => provider.description = val,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.updateSettings(context),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
