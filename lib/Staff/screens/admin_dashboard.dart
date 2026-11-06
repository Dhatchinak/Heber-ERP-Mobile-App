// admin_dashboard.dart
// Mirrors the web admin portal's module list. Staff Master ships first and
// fully works (enter a Staff ID -> land in that staff's dashboard, same as
// "Remote View" on the website). Everything else is the same module list
// from the web app, added here as placeholders to be built out next.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import 'staff_master_screen.dart';

class _AdminModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool ready;
  const _AdminModule(this.title, this.subtitle, this.icon, {this.ready = false});
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  // Same modules as the web admin panel's (admin) pages — built out in order.
  static const _modules = [
    _AdminModule('Staff Master', 'Look up a staff ID and open their dashboard',
        Icons.badge, ready: true),
    _AdminModule('Staff Management', 'All staff records', Icons.groups),
    _AdminModule('Student Management', 'All student records', Icons.school),
    _AdminModule('Biometric Master', 'Biometric attendance overview', Icons.fingerprint),
    _AdminModule('Fees Generate', 'Generate & manage fee structures', Icons.receipt_long),
    _AdminModule('Department Settings', 'Departments & programs', Icons.apartment),
    _AdminModule('System Logs', 'Audit & activity logs', Icons.list_alt),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        backgroundColor: Colors.red[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _modules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final m = _modules[i];
          return Card(
            elevation: m.ready ? 2 : 0,
            color: m.ready ? null : Colors.grey[100],
            child: ListTile(
              leading: Icon(m.icon, color: m.ready ? Colors.red[700] : Colors.grey),
              title: Text(m.title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: m.ready ? Colors.black : Colors.grey)),
              subtitle: Text(m.subtitle, style: const TextStyle(fontSize: 12)),
              trailing: m.ready
                  ? const Icon(Icons.chevron_right)
                  : const Text('Coming soon', style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: m.ready
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StaffMasterScreen()),
                      )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
