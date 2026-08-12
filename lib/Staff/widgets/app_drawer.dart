import 'dart:convert';

import 'package:bhc_erp/Staff/common/Alt_Attendance.dart';
import 'package:bhc_erp/Staff/common/MentoringFormActivity%20.dart';
import 'package:bhc_erp/Staff/common/StaffBioAttendance.dart';
import 'package:bhc_erp/Staff/common/TimeTable.dart';
import 'package:bhc_erp/Staff/common/academic_calendar.dart';
import 'package:bhc_erp/Staff/common/class_attendance.dart';
import 'package:bhc_erp/Staff/common/hall_booking/booking_calendar_screen.dart';
import 'package:bhc_erp/Staff/common/hall_booking/bookings_list_screen.dart';
import 'package:bhc_erp/Staff/common/hall_booking/hall_booking_screen.dart';
import 'package:bhc_erp/Staff/common/hall_booking/room_booking_screen.dart';
import 'package:bhc_erp/Staff/common/profile.dart';
import 'package:bhc_erp/Staff/common/publications.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:bhc_erp/core/auth/auth_provider.dart';

const String _kBaseApiUrl = 'https://apierp.bhc.edu.in/api';
const String _kRefererUrl = 'http://117.232.64.75';

class AppDrawer extends StatelessWidget {
  final bool isHod;
  final String? currentRoute;

  const AppDrawer({super.key, this.isHod = false, this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);
    final authProvider = context.read<AuthProvider>();
    final userData = authProvider.userData;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(right: BorderSide(color: theme.border, width: 1)),
        ),
        child: Column(
          children: [
            _DrawerHeader(
              theme: theme,
              userData: userData,
              isHod: isHod,
            ),
            Expanded(
              child: _DrawerNav(
                theme: theme,
                isHod: isHod,
                currentRoute: currentRoute,
              ),
            ),
            _DrawerFooter(theme: theme),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatefulWidget {
  final StaffThemeProvider theme;
  final Map<String, dynamic>? userData;
  final bool isHod;

  const _DrawerHeader({
    required this.theme,
    required this.userData,
    required this.isHod,
  });

  @override
  State<_DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<_DrawerHeader> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _fetchPhoto();
  }

  Future<void> _fetchPhoto() async {
    final staffId = widget.userData?['staff_id']?.toString();
    if (staffId == null) return;
    try {
      final res = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/photo/staff/$staffId'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['view_url'] != null) {
          if (mounted) setState(() => _photoUrl = data['view_url'].toString());
        }
      }
    } catch (_) {}
  }

  String _initials(String n) {
    if (n.isEmpty) return '?';
    final parts = n.trim().split(' ');
    return parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final name = widget.userData?['name'] ?? 'Staff Member';
    final designation = widget.userData?['designation'] ?? '';
    final department = widget.userData?['department_name'] ?? '';
    final staffId = widget.userData?['staff_id'] ?? '';
    final accent = widget.isHod ? theme.amber : theme.cyan;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.elevated, theme.elevated2],
        ),
        border: Border(bottom: BorderSide(color: theme.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: accent.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withOpacity(0.25), blurRadius: 12)
                      ],
                    ),
                    child: ClipOval(
                      child: _photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _photoUrl!,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              placeholder: (_, __) => Container(
                                color: theme.elevated,
                                child: Center(
                                  child: Text(
                                    _initials(name),
                                    style: TextStyle(
                                        color: accent,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: theme.elevated,
                                child: Center(
                                  child: Text(
                                    _initials(name),
                                    style: TextStyle(
                                        color: accent,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: theme.elevated,
                              child: Center(
                                child: Text(
                                  _initials(name),
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.surface, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: theme.green.withOpacity(0.5), blurRadius: 4)
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                          color: theme.textHigh,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    widget.isHod
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: theme.amber.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium,
                                    size: 11, color: theme.amber),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    designation,
                                    style: TextStyle(
                                        color: theme.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.cyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: theme.cyan.withOpacity(0.3)),
                            ),
                            child: Text(
                              staffId,
                              style: TextStyle(
                                  color: theme.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.bg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business_center_rounded,
                      size: 12, color: theme.violet),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Department',
                            style: TextStyle(
                                color: theme.textLow,
                                fontSize: 9,
                                fontWeight: FontWeight.w500)),
                        Text(department,
                            style: TextStyle(
                                color: theme.textHigh,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.badge_rounded, size: 12, color: theme.cyan),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff ID',
                            style: TextStyle(
                                color: theme.textLow,
                                fontSize: 9,
                                fontWeight: FontWeight.w500)),
                        Text(staffId,
                            style: TextStyle(
                                color: theme.textHigh,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
                if (!widget.isHod && designation.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.violet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.violet.withOpacity(0.25)),
                    ),
                    child: Text(
                      designation.length > 12
                          ? '${designation.substring(0, 12)}…'
                          : designation,
                      style: TextStyle(
                          color: theme.violet,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  final StaffThemeProvider theme;

  const _AvatarFallback({required this.name, required this.theme});

  String _initials(String n) {
    if (n.isEmpty) return '?';
    final parts = n.split(' ');
    return parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.elevated,
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
              color: theme.cyan, fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _DrawerNav extends StatelessWidget {
  final StaffThemeProvider theme;
  final bool isHod;
  final String? currentRoute;

  const _DrawerNav({
    required this.theme,
    required this.isHod,
    this.currentRoute,
  });

  bool _isActive(String routeName) {
    if (currentRoute == null) return false;
    return currentRoute == routeName;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final staffId = authProvider.userData?['staff_id'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavSection(
            title: 'MAIN',
            theme: theme,
            items: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                isSelected: _isActive('/dashboard'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/dashboard'),
              ),
            ],
          ),
          _NavSection(
            title: 'ACADEMICS',
            theme: theme,
            items: [
              _NavItem(
                icon: Icons.person_rounded,
                label: 'My Profile',
                isSelected: _isActive('/profile'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/profile',
                    page: const StaffProfileScreen()),
              ),
              _NavItem(
                icon: Icons.article_rounded,
                label: 'Publications',
                isSelected: _isActive('/publications'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/publications',
                    page: const EnhancedPublicationsScreen()),
              ),
              _NavItem(
                icon: Icons.calendar_today_rounded,
                label: 'Class Attendance',
                isSelected: _isActive('/class-attendance'),
                theme: theme,
                onTap: () => _navigateToRoute(
                  context,
                  '/class-attendance',
                  page: ProfessionalClassAttendanceScreen(
                    staffId: staffId,
                    baseApiUrl: _kBaseApiUrl,
                    refererUrl: _kRefererUrl,
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.event_available_rounded,
                label: 'Alternative Attendance',
                isSelected: _isActive('/alt-attendance'),
                theme: theme,
                onTap: () => _navigateToRoute(
                  context,
                  '/alt-attendance',
                  page: AlternativeAttendanceScreen(staffId: staffId),
                ),
              ),
              _NavItem(
                icon: Icons.schedule_rounded,
                label: 'Timetable',
                isSelected: _isActive('/timetable'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/timetable',
                    page: const StaffTimetableScreen()),
              ),
            ],
          ),
          _NavSection(
            title: 'MENTORSHIP',
            theme: theme,
            items: [
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Mentoring',
                isSelected: _isActive('/mentoring'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/mentoring',
                    page: const UnifiedMentoringDashboard()),
              ),
            ],
          ),
          _NavSection(
            title: 'ATTENDANCE',
            theme: theme,
            items: [
              _NavItem(
                icon: Icons.fingerprint_rounded,
                label: 'Bio Attendance',
                isSelected: _isActive('/bio-attendance'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/bio-attendance',
                    page: const StaffBioAttendanceScreen()),
              ),
            ],
          ),
          _NavSection(
            title: 'FACILITIES',
            theme: theme,
            items: [
              _NavItem(
                icon: Icons.meeting_room_rounded,
                label: 'Book Hall',
                isSelected: _isActive('/hall-booking'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/hall-booking',
                    page: const HallBookingScreen()),
              ),
              _NavItem(
                icon: Icons.hotel_rounded,
                label: 'Book Room',
                isSelected: _isActive('/room-booking'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/room-booking',
                    page: const RoomBookingScreen()),
              ),
              _NavItem(
                icon: Icons.list_alt_rounded,
                label: 'My Bookings',
                isSelected: _isActive('/my-bookings'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/my-bookings',
                    page: const MyBookingsScreen()),
              ),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Booking Calendar',
                isSelected: _isActive('/booking-calendar'),
                theme: theme,
                onTap: () => _navigateToRoute(context, '/booking-calendar',
                    page: const BookingCalendarScreen()),
              ),
            ],
          ),
          _NavSection(
            title: 'CAMPUS',
            theme: theme,
            items: [
              _NavItem(
                icon: Icons.event_rounded,
                label: 'Academic Calendar',
                isSelected: _isActive('/academic-calendar'),
                theme: theme,
                onTap: () => _navigateToRoute(
                  context,
                  '/academic-calendar',
                  page: AcademicCalendarScreen(
                    rollNo: '',
                    studentName: '',
                  ),
                ),
              ),
            ],
          ),
          if (isHod)
            _NavSection(
              title: 'HOD TOOLS',
              theme: theme,
              items: [
                _NavItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Faculty Overview',
                  theme: theme,
                  badge: 'HOD',
                  onTap: () => _showComingSoon(context, 'Faculty Overview'),
                ),
                _NavItem(
                  icon: Icons.assessment_rounded,
                  label: 'Department Reports',
                  theme: theme,
                  badge: 'HOD',
                  onTap: () => _showComingSoon(context, 'Department Reports'),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _navigateToRoute(BuildContext context, String routeName,
      {Widget? page}) {
    Navigator.pop(context);

    if (routeName == '/dashboard') {
      Navigator.pushNamedAndRemoveUntil(
          context, '/staff-dashboard', (route) => false);
      return;
    }

    if (page == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (_) => page,
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.surface,
        title: Text('$feature — Coming Soon',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textHigh)),
        content: Text(
            'This feature is under development and will be available soon.',
            style: TextStyle(color: theme.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: theme.cyan)),
          ),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String title;
  final StaffThemeProvider theme;
  final List<_NavItem> items;

  const _NavSection({
    required this.title,
    required this.theme,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.textLow,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...items,
        const SizedBox(height: 4),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final StaffThemeProvider theme;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.isSelected = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? theme.cyan : theme.textMid;

    // FIX: wrap ListTile in Material(color: transparent)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minLeadingWidth: 0,
          horizontalTitleGap: 12,
          tileColor:
              isSelected ? theme.cyan.withOpacity(0.08) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: theme.cyan.withOpacity(0.25))
                : BorderSide.none,
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? theme.cyan.withOpacity(0.15) : theme.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? theme.cyan.withOpacity(0.4) : theme.border,
                width: isSelected ? 1 : 0.5,
              ),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? theme.cyan : theme.textMid,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.amber.withOpacity(0.4)),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: theme.amber),
                  ),
                ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: theme.cyan.withOpacity(0.6)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  final StaffThemeProvider theme;

  const _DrawerFooter({required this.theme});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Column(
        children: [
          // Theme Toggle — FIX: Material wraps ListTile directly
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              minLeadingWidth: 0,
              horizontalTitleGap: 12,
              tileColor: theme.cyan.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.cyan.withOpacity(0.2)),
              ),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  theme.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: theme.cyan,
                  size: 17,
                ),
              ),
              title: Text(
                theme.isDarkMode ? "Dark Mode" : "Light Mode",
                style: TextStyle(
                    color: theme.textHigh,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              trailing: Switch(
                value: theme.isDarkMode,
                onChanged: (_) => theme.toggleTheme(),
                activeColor: theme.cyan,
                activeTrackColor: theme.cyan.withOpacity(0.3),
                inactiveThumbColor: theme.textMid,
                inactiveTrackColor: theme.border,
              ),
              onTap: () => theme.toggleTheme(),
            ),
          ),
          const SizedBox(height: 8),
          // Logout — FIX: Material wraps ListTile directly
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              onTap: () => _handleLogout(context, authProvider),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              minLeadingWidth: 0,
              horizontalTitleGap: 12,
              tileColor: theme.pink.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.pink.withOpacity(0.2)),
              ),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.pink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded, color: theme.pink, size: 17),
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.pink),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Heber ERP v1.0.0',
            style: TextStyle(
                color: theme.textLow, fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.surface,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.pink.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.pink.withOpacity(0.3)),
                ),
                child: Icon(Icons.power_settings_new_rounded,
                    color: theme.pink, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Sign Out',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textHigh)),
              const SizedBox(height: 8),
              Text('Are you sure you want to logout?',
                  style: TextStyle(fontSize: 13, color: theme.textMid)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.border),
                        foregroundColor: theme.textMid,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/login', (route) => false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Logout',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
