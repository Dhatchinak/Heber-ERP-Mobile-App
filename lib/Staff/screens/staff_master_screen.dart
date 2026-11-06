// staff_master_screen.dart
// Admin -> enter a Staff ID -> land straight in that staff's dashboard,
// same as clicking "Remote View" on a staff row in the web admin panel.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../widgets/impersonation_banner.dart';
import 'staff_dashboard.dart';

class StaffMasterScreen extends StatefulWidget {
  const StaffMasterScreen({super.key});

  @override
  State<StaffMasterScreen> createState() => _StaffMasterScreenState();
}

class _StaffMasterScreenState extends State<StaffMasterScreen> {
  final _staffIdController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _goToStaff() async {
    final id = _staffIdController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter a Staff ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().impersonateStaff(id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ImpersonationBanner(child: StaffDashboard()),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _staffIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Master'),
        backgroundColor: Colors.red[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a Staff ID to open that staff member\'s dashboard '
              '(same as "Remote View" on the web portal).',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _staffIdController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Staff ID',
                hintText: 'e.g. BHC1234',
                border: const OutlineInputBorder(),
                errorText: _error,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              onSubmitted: (_) => _loading ? null : _goToStaff(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _goToStaff,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login),
                label: Text(_loading ? 'Opening...' : 'Go to Staff Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
