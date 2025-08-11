import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sv_invoice_scanner/providers/settings.provider.dart';

class SettingsToggleButton extends StatefulWidget {
  const SettingsToggleButton({super.key});

  @override
  State<SettingsToggleButton> createState() => _SettingsToggleButtonState();
}

class _SettingsToggleButtonState extends State<SettingsToggleButton> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    provider.fetchSettings();
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, _) {
        return IconButton(
          tooltip: provider.isScanWithAi ? 'Disable AI Scan' : 'Enable AI Scan',
          icon: provider.isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  provider.isScanWithAi ? Icons.toggle_on : Icons.toggle_off,
                  color: provider.isScanWithAi
                      ? Colors.green
                      : Theme.of(context).colorScheme.onPrimary,
                  size: 32,
                ),
          onPressed: provider.isLoading
              ? null
              : () async {
                  provider.isScanWithAi = !provider.isScanWithAi;
                  await provider.updateSettings(context);
                },
        );
      },
    );
  }
}
