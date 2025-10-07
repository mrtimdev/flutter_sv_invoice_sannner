import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/driver.dart';
import '../../providers/driver_provider.dart';
import 'form.dart';

class DriverIndexScreen extends StatefulWidget {
  const DriverIndexScreen({Key? key}) : super(key: key);

  @override
  State<DriverIndexScreen> createState() => _DriverIndexScreenState();
}

class _DriverIndexScreenState extends State<DriverIndexScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DriverProvider>(context, listen: false).loadDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DriverProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadDrivers(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _navigateToFormScreen(),
      ),
      body: _buildBody(provider, theme),
    );
  }

  Widget _buildBody(DriverProvider provider, ThemeData theme) {
    if (provider.isLoading && provider.drivers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.error!),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => provider.loadDrivers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadDrivers(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: provider.drivers.length,
        itemBuilder: (context, index) {
          final driver = provider.drivers[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                child: Text(
                  driver.firstName.substring(0, 1),
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                '${driver.firstName} ${driver.lastName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Phone: ${driver.phone}'),
                  Text('Plate: ${driver.plateNumber}'),
                ],
              ),
              trailing: PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Edit'),
                    onTap: () => Future.delayed(
                      Duration.zero,
                      () => _navigateToFormScreen(driver: driver),
                    ),
                  ),
                  PopupMenuItem(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () => Future.delayed(
                      Duration.zero,
                      () => _confirmDelete(driver.id!),
                    ),
                  ),
                ],
              ),
              onTap: () => _navigateToFormScreen(driver: driver),
            ),
          );
        },
      ),
    );
  }

  Future<void> _navigateToFormScreen({Driver? driver}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverFormScreen(driver: driver),
      ),
    );

    if (result == true) {
      Provider.of<DriverProvider>(context, listen: false).loadDrivers();
    }
  }

  Future<void> _confirmDelete(int driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<DriverProvider>(context, listen: false)
          .deleteDriver(driverId);
    }
  }
}