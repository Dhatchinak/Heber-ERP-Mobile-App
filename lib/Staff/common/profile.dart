// staff_profile_screen.dart
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? staffData;
  bool isLoading = true;
  String errorMessage = "";
  String? photoUrl;
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _appBarGlow;
  late List<Animation<double>> _stagger;

  String? _staffId;

  final String _baseApiUrl = "https://apierp.bhc.edu.in/api/staff/";
  final String _workingPhotoIp = "apierp.bhc.edu.in";
  final String _refererUrl = "http://117.232.64.75";

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _stagger = List.generate(
        8,
        (i) => CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
            ));
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_staffId == null) _initializeData();
  }

  void _initializeData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _staffId = authProvider.userData?['staff_id']?.toString();

    if (_staffId != null) {
      fetchStaffData();
      _fetchStaffPhoto();
    } else {
      setState(() {
        errorMessage = "Staff ID not found. Please login again.";
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

Future<void> _fetchStaffPhoto() async {
  if (_staffId == null) return;
  try {
    final res = await http.get(
      Uri.parse('https://apierp.bhc.edu.in/photo/staff/$_staffId'),
      headers: {'Referer': 'http://117.232.64.75', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['success'] == true && data['view_url'] != null) {
        if (mounted) setState(() => photoUrl = data['view_url'].toString());
      }
    }
  } catch (e) {
    debugPrint('Photo error: $e');
  }
}

  Future<void> fetchStaffData() async {
    try {
      if (_staffId == null) {
        setState(() {
          errorMessage = "Staff ID not found. Please login again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("$_baseApiUrl$_staffId"),
        headers: {
          'Referer': _refererUrl,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response body');
        }
        final jsonResponse = json.decode(response.body);
        if (jsonResponse is Map && jsonResponse.isEmpty) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          setState(() {
            staffData = authProvider.userData;
            isLoading = false;
          });
        } else {
          setState(() {
            staffData = jsonResponse;
            isLoading = false;
          });
        }
        _staggerCtrl.forward();
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        setState(() {
          errorMessage =
              "API Error: ${response.statusCode}. Showing local data.";
          staffData = authProvider.userData;
          isLoading = false;
        });
        _staggerCtrl.forward();
      }
    } catch (e) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        errorMessage = "Network Error: $e. Showing local data.";
        staffData = authProvider.userData;
        isLoading = false;
      });
      _staggerCtrl.forward();
    }
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(_stagger[i]),
          child: child,
        ),
      );

  // ─── FUTURISTIC APP BAR ─────────────────────────────────────────────────
  PreferredSizeWidget _buildFuturisticAppBar(StaffThemeProvider theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.cyan.withOpacity(0.2 + _appBarGlow.value * 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      theme.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: theme.elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.border),
                        ),
                        child: Icon(Icons.menu_rounded,
                            color: theme.textHigh, size: 18),
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: theme.cyan.withOpacity(0.3), blurRadius: 10)
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.elevated,
                          child: Icon(Icons.school_rounded,
                              color: theme.cyan, size: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Staff Profile",
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      Text("Personal Information",
                          style: TextStyle(
                              color: theme.cyan.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.green,
                            boxShadow: [
                              BoxShadow(
                                  color: theme.green.withOpacity(0.6),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text("PROFILE",
                            style: TextStyle(
                                color: theme.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        color: theme.textMid, size: 20),
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                        errorMessage = "";
                      });
                      fetchStaffData();
                      _fetchStaffPhoto();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── DRAWER ─────────────────────────────────────────────────────────────
Widget _buildDrawer(StaffThemeProvider theme) {
  final authProvider = context.read<AuthProvider>();
  final isHod = authProvider.userRole == UserRole.hod;

  return AppDrawer(
    isHod: isHod,
    currentRoute: '/profile', // Pass current route
  );
}

  // ─── HERO HEADER ─────────────────────────────────────────────────────────
  Widget _buildHeroHeader(StaffThemeProvider theme) {
    final name =
        "${staffData?['salute'] ?? ''} ${staffData?['name'] ?? 'Staff Member'}"
            .trim();
    final designation = staffData?['designation'] ?? 'Teaching Faculty';
    final department = staffData?['department_name'] ?? 'Department';
    final staffId = staffData?['staff_id'] ?? 'N/A';
    final isActive = staffData?['isActive'] == true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.elevated, theme.elevated2, theme.surface],
        ),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32)),
            child: CustomPaint(
              painter: _GridPainter(color: theme.cyan.withOpacity(0.04)),
              size: const Size(double.infinity, 360),
            ),
          ),
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Positioned(
              top: -30 + _glowCtrl.value * 10,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.cyan.withOpacity(0.05 + _glowCtrl.value * 0.03),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 106 + _pulseCtrl.value * 4,
                        height: 106 + _pulseCtrl.value * 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.cyan
                              .withOpacity(0.08 + _pulseCtrl.value * 0.04),
                          boxShadow: [
                            BoxShadow(
                                color: theme.cyan
                                    .withOpacity(0.25 + _pulseCtrl.value * 0.1),
                                blurRadius: 24)
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.cyan.withOpacity(0.5), width: 2.5),
                        color: theme.elevated,
                      ),
                      child: ClipOval(
                        child: photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: photoUrl!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                httpHeaders: const {
                                  "Referer": "https://apierp.bhc.edu.in"
                                },
                                placeholder: (_, __) => Container(
                                  color: theme.elevated,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: theme.cyan),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: theme.elevated,
                                  child: Icon(Icons.person_rounded,
                                      size: 44, color: theme.cyan),
                                ),
                              )
                            : Icon(Icons.person_rounded,
                                size: 44, color: theme.cyan),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: theme.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.bg, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: theme.green.withOpacity(0.5),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.verified_rounded,
                          size: 14, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.textHigh,
                      letterSpacing: -0.3,
                      height: 1.1),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.cyan.withOpacity(0.35)),
                  ),
                  child: Text(staffId,
                      style: TextStyle(
                          color: theme.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 10),
                Text(designation,
                    style: TextStyle(
                        color: theme.textMid,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(department,
                    style: TextStyle(color: theme.textMid, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _quickBadge(
                        theme,
                        Icons.work_rounded,
                        staffData?['employee_type']?.toString().toUpperCase() ??
                            'Staff',
                        theme.cyan),
                    const SizedBox(width: 10),
                    _quickBadge(
                        theme,
                        Icons.check_circle_rounded,
                        isActive ? "Active" : "Inactive",
                        isActive ? theme.green : theme.amber),
                    if (staffData?['isDoctorate'] == true) ...[
                      const SizedBox(width: 10),
                      _quickBadge(theme, Icons.school_rounded, "Doctorate",
                          theme.violet),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBadge(
      StaffThemeProvider theme, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── INFO CARD ───────────────────────────────────────────────────────────
  Widget _infoCard(StaffThemeProvider theme, String title, IconData icon,
      Color color, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 16)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18)),
              border:
                  Border(bottom: BorderSide(color: color.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(children: rows)),
        ],
      ),
    );
  }

  Widget _infoRow(StaffThemeProvider theme, String label, String value,
      {IconData? icon, Color? color}) {
    final display = value.isNotEmpty ? value : "Not Available";
    final hasValue = value.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (color ?? theme.textLow).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (color ?? theme.textLow).withOpacity(0.2)),
              ),
              child: Icon(icon, size: 15, color: color ?? theme.textMid),
            ),
            const SizedBox(width: 12),
          ] else ...[
            const SizedBox(width: 44)
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textMid,
                        fontSize: 11,
                        letterSpacing: 0.2)),
                const SizedBox(height: 3),
                Text(display,
                    style: TextStyle(
                        fontSize: 13,
                        color: hasValue ? theme.textHigh : theme.textLow,
                        fontWeight: FontWeight.w500,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PUBLICATIONS SECTION ────────────────────────────────────────────────
  Widget _buildPublicationsSection(StaffThemeProvider theme) {
    final publications = staffData?['publications'] ?? {};
    final journalArticles = publications['journal_articles']?.length ?? 0;
    final conferencePapers = publications['conference_papers']?.length ?? 0;
    final bookChapters = publications['book_chapters']?.length ?? 0;
    final booksAuthored = publications['books_authored']?.length ?? 0;
    final total =
        journalArticles + conferencePapers + bookChapters + booksAuthored;

    return _infoCard(
      theme,
      "Research Publications",
      Icons.library_books_rounded,
      theme.violet,
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.violet.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.violet.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text("$total",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: theme.violet)),
                  Text("Total Publications",
                      style: TextStyle(fontSize: 11, color: theme.textMid)),
                ],
              ),
              Icon(Icons.article_rounded, color: theme.violet, size: 40),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pubStat(theme, "Journal", journalArticles, theme.cyan),
            _pubStat(theme, "Conference", conferencePapers, theme.green),
            _pubStat(theme, "Book Chapters", bookChapters, theme.amber),
            _pubStat(theme, "Books", booksAuthored, theme.pink),
          ],
        ),
      ],
    );
  }

  Widget _pubStat(
      StaffThemeProvider theme, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text("$count",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: theme.textMid,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── ADDRESS SECTION ─────────────────────────────────────────────────────
  Widget _buildAddressSection(StaffThemeProvider theme) {
    final address = staffData?['address'] ?? {};
    final present = address['present'] ?? {};

    return _infoCard(
      theme,
      "Address Information",
      Icons.location_on_rounded,
      theme.green,
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.green.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.green.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.home_work_rounded, size: 14, color: theme.green),
                  const SizedBox(width: 8),
                  Text("Present Address",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textHigh)),
                ],
              ),
              const SizedBox(height: 8),
              if (present['street'] != null)
                Text(present['street'],
                    style: TextStyle(fontSize: 12, color: theme.textMid)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  _addressChip(theme, present['city'] ?? 'N/A', theme.cyan),
                  _addressChip(theme, present['state'] ?? 'N/A', theme.violet),
                  _addressChip(theme, "PIN: ${present['pincode'] ?? 'N/A'}",
                      theme.amber),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addressChip(StaffThemeProvider theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  // ─── LOADING / ERROR STATES ─────────────────────────────────────────────
  Widget _buildLoadingState(StaffThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.08 + _pulseCtrl.value * 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: theme.cyan.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.cyan,
                      backgroundColor: theme.cyan.withOpacity(0.1)),
                  Icon(Icons.person_rounded,
                      size: 24, color: theme.cyan.withOpacity(0.6)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text("Loading Profile...",
              style: TextStyle(
                  fontSize: 14,
                  color: theme.textMid,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text("Fetching your data",
              style: TextStyle(fontSize: 12, color: theme.textLow)),
        ],
      ),
    );
  }

  Widget _buildErrorState(StaffThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                  color: theme.pink.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.pink.withOpacity(0.3))),
              child: Icon(Icons.error_outline_rounded,
                  size: 44, color: theme.pink),
            ),
            const SizedBox(height: 22),
            Text("Unable to Load Profile",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textHigh)),
            const SizedBox(height: 10),
            Text(errorMessage,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: theme.textMid, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = "";
                });
                fetchStaffData();
                _fetchStaffPhoto();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Try Again",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.cyan.withOpacity(0.15),
                foregroundColor: theme.cyan,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.cyan)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MAIN BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bg,
      drawer: _buildDrawer(theme),
      appBar: _buildFuturisticAppBar(theme),
      body: isLoading
          ? _buildLoadingState(theme)
          : errorMessage.isNotEmpty
              ? _buildErrorState(theme)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeroHeader(theme),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                        child: Column(
                          children: [
                            _animated(
                                0,
                                _infoCard(theme, "Personal Information",
                                    Icons.person_rounded, theme.cyan, [
                                  _infoRow(theme, "Full Name",
                                      "${staffData?['salute'] ?? ''} ${staffData?['name'] ?? ''}",
                                      icon: Icons.person_outline_rounded,
                                      color: theme.cyan),
                                  _infoRow(theme, "Gender",
                                      staffData?['gender'] ?? 'N/A',
                                      icon: Icons.transgender_rounded,
                                      color: theme.pink),
                                  _infoRow(theme, "Date of Birth",
                                      staffData?['dob'] ?? 'N/A',
                                      icon: Icons.cake_rounded,
                                      color: theme.violet),
                                  _infoRow(theme, "Blood Group",
                                      staffData?['blood_group'] ?? 'N/A',
                                      icon: Icons.bloodtype_rounded,
                                      color: theme.pink),
                                  _infoRow(theme, "Nationality",
                                      staffData?['nationality'] ?? 'N/A',
                                      icon: Icons.flag_rounded,
                                      color: theme.green),
                                ])),
                            const SizedBox(height: 14),
                            _animated(
                                1,
                                _infoCard(theme, "Professional Information",
                                    Icons.work_rounded, theme.violet, [
                                  _infoRow(
                                    theme,
                                    "Staff ID",
                                    staffData?['staff_id'] ?? 'N/A',
                                    icon: Icons.badge_rounded,
                                    color: theme.cyan,
                                  ),
                                  _infoRow(theme, "Designation",
                                      staffData?['designation'] ?? 'N/A',
                                      icon: Icons.work_outline_rounded,
                                      color: theme.violet),
                                  _infoRow(theme, "Department",
                                      staffData?['department_name'] ?? 'N/A',
                                      icon: Icons.business_rounded,
                                      color: theme.green),
                                  _infoRow(
                                      theme,
                                      "Employee Type",
                                      staffData?['employee_type']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'N/A',
                                      icon: Icons.category_rounded,
                                      color: theme.amber),
                                  _infoRow(theme, "Joining Date",
                                      staffData?['joining_date'] ?? 'N/A',
                                      icon: Icons.date_range_rounded,
                                      color: theme.cyan),
                                ])),
                            const SizedBox(height: 14),
                            _animated(
                                2,
                                _infoCard(theme, "Contact Information",
                                    Icons.contact_mail_rounded, theme.green, [
                                  _infoRow(theme, "College Email",
                                      staffData?['college_email'] ?? 'N/A',
                                      icon: Icons.email_rounded,
                                      color: theme.pink),
                                  _infoRow(theme, "Phone",
                                      staffData?['phone']?.toString() ?? 'N/A',
                                      icon: Icons.phone_rounded,
                                      color: theme.green),
                                ])),
                            const SizedBox(height: 14),
                            if (staffData?['address'] != null)
                              _animated(3, _buildAddressSection(theme)),
                            const SizedBox(height: 14),
                            if (staffData?['publications'] != null)
                              _animated(4, _buildPublicationsSection(theme)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── GRID PAINTER ─────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const sp = 28.0;
    for (double x = 0; x <= size.width; x += sp)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y <= size.height; y += sp)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
