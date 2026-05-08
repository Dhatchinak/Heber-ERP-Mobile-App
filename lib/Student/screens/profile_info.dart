import 'package:bhc_erp/Student/services/photo_service.dart';
import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


const String baseApiUrl = 'https://apierp.bhc.edu.in';
const String refererUrl = 'http://117.232.64.75';

class ProfileScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;
  const ProfileScreen({super.key, required this.rollNo, required this.studentName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? studentData;
  bool isLoading = true;
  String errorMessage = "";
  String? photoUrl;
  String? _studentName;

  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _appBarGlow;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _staggerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    );
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _stagger = List.generate(8, (i) => CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
    ));

    // Run all init in parallel
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    // Load name from prefs first (fast)
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _studentName = prefs.getString('studentName') ?? widget.studentName;
      });
    }

    // Photo + data in parallel
    await Future.wait([
      _fetchStudentPhoto(),
      _fetchStudentData(),
    ]);
  }

  // ─── PHOTO ───────────────────────────────────────────────────────────────
Future<void> _fetchStudentPhoto() async {
  final rollNo = widget.rollNo.trim();
  if (rollNo.isEmpty) return;

  try {
    // Try cache first - NO HEAD REQUEST (let CachedNetworkImage handle it)
    String? cached = await PhotoService.getCachedPhotoUrl(rollNo);
    if (cached != null && mounted) {
      setState(() => photoUrl = cached);
      return;
    }

    // Fetch fresh
    final fresh = await PhotoService.getStudentPhotoUrl(rollNo);
    if (fresh != null && mounted) {
      setState(() => photoUrl = fresh);
      await PhotoService.cacheStudentPhoto(rollNo);
    }
  } catch (e) {
    debugPrint('Photo error: $e');
  }
}

  // ─── DATA ────────────────────────────────────────────────────────────────
  Future<void> _fetchStudentData() async {
    if (!mounted) return;
    if (mounted) setState(() { isLoading = true; errorMessage = ""; });

    try {
      final response = await http.get(
        Uri.parse("$baseApiUrl/api/students/${widget.rollNo}"),
        headers: {
          'Referer': refererUrl,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Also update name from API if available
        final apiName = json["data"]?["name"] as String?;
        setState(() {
          studentData = json["data"];
          isLoading = false;
          if (apiName != null && apiName.isNotEmpty) _studentName = apiName;
        });
        _staggerCtrl.forward();
      } else {
        setState(() {
          errorMessage = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Connection error. Check your internet.";
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    _staggerCtrl.reset();
    await Future.wait([
      _fetchStudentPhoto(),
      _fetchStudentData(),
    ]);
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ─── APP BAR ─────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildFuturisticAppBar(ThemeProvider c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(
              bottom: BorderSide(
                color: c.violet.withOpacity(0.2 + _appBarGlow.value * 0.15),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: c.violet.withOpacity(0.06 + _appBarGlow.value * 0.04),
                blurRadius: 20,
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
                        color: c.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.menu_rounded, color: c.textHigh, size: 18),
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.violet.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_rounded, color: c.violet, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Student Profile",
                          style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text("Personal Information",
                          style: TextStyle(
                            color: c.violet.withOpacity(0.8),
                            fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1,
                          )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.green,
                          boxShadow: [BoxShadow(color: c.green.withOpacity(0.6), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text("ACTIVE",
                          style: TextStyle(color: c.green, fontSize: 10,
                              fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 20),
                  onPressed: _refreshData,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(
        rollNo: widget.rollNo,
        studentName: _studentName ?? widget.studentName,
        currentRoute: '/profile',
      ),
      appBar: _buildFuturisticAppBar(c),
      body: isLoading
          ? _buildLoadingState(c)
          : errorMessage.isNotEmpty
              ? _buildErrorState(c)
              : _buildContent(c),
    );
  }

  Widget _buildContent(ThemeProvider c) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeroHeader(c),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              children: [
                _animated(0, _infoCard("ACADEMIC DETAILS", Icons.school_rounded, c.cyan, _academicRows(c), c)),
                const SizedBox(height: 14),
                _animated(1, _infoCard("PERSONAL INFORMATION", Icons.person_rounded, c.violet, _personalRows(c), c)),
                const SizedBox(height: 14),
                _animated(2, _infoCard("FAMILY DETAILS", Icons.family_restroom_rounded, c.amber, _familyRows(c), c)),
                const SizedBox(height: 14),
                _animated(3, _infoCard("CONTACT INFORMATION", Icons.contact_phone_rounded, c.green, _contactRows(c), c)),
                if (studentData?["academic_info"] != null &&
                    (studentData!["academic_info"] as List).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _animated(4, _infoCard("PREVIOUS ACADEMIC", Icons.history_edu_rounded, c.pink, _prevAcademicRows(c), c)),
                ],
                const SizedBox(height: 14),
                _animated(5, _infoCard("ADDITIONAL INFO", Icons.info_rounded, c.cyan, _additionalRows(c), c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animated(int i, Widget child) => FadeTransition(
    opacity: _stagger[i],
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
          .animate(_stagger[i]),
      child: child,
    ),
  );

  // ─── HERO HEADER ─────────────────────────────────────────────────────────
  Widget _buildHeroHeader(ThemeProvider c) {
    final name = studentData?["name"] ?? _studentName ?? widget.studentName;
    final rollNo = studentData?["roll_no"]?.toString() ?? widget.rollNo;
    final batch = studentData?["batch"] ?? "";
    final stream = studentData?["stream"] ?? "";
    final program = studentData?["current_academic"]?["program_name"] ?? "";

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.isDarkMode ? const Color(0xFF0D1A3A) : c.bg,
            c.isDarkMode ? const Color(0xFF0F1E45) : c.surface,
            c.bg,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Grid background
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: CustomPaint(
              painter: _GridPainter(color: c.violet.withOpacity(0.04)),
              size: const Size(double.infinity, 300),
            ),
          ),
          // Glow orb
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Positioned(
              top: -30 + _glowCtrl.value * 10,
              right: -20,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.violet.withOpacity(0.05 + _glowCtrl.value * 0.03),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              children: [
                // ── PHOTO ──────────────────────────────────────────────────
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Pulse ring
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 106 + _pulseCtrl.value * 6,
                        height: 106 + _pulseCtrl.value * 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.violet.withOpacity(0.08 + _pulseCtrl.value * 0.04),
                          boxShadow: [
                            BoxShadow(
                              color: c.violet.withOpacity(0.25 + _pulseCtrl.value * 0.15),
                              blurRadius: 24 + _pulseCtrl.value * 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Photo circle
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.violet.withOpacity(0.6), width: 2.5),
                        color: c.elevated,
                        boxShadow: [
                          BoxShadow(
                            color: c.violet.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: photoUrl!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                // FIX: correct headers with http:// Referer
                                httpHeaders: PhotoService.headers,
                                placeholder: (_, __) => _photoPlaceholder(c),
                                errorWidget: (_, __, ___) => _photoFallback(c),
                              )
                            : _photoFallback(c),
                      ),
                    ),
                    // Verified badge
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: c.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 2),
                        boxShadow: [
                          BoxShadow(color: c.green.withOpacity(0.5), blurRadius: 8),
                        ],
                      ),
                      child: const Icon(Icons.verified_rounded, size: 14, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Name
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: c.textHigh, letterSpacing: -0.3, height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Roll No chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.cyan.withOpacity(0.35)),
                  ),
                  child: Text(rollNo,
                      style: TextStyle(color: c.cyan, fontSize: 13,
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                const SizedBox(height: 10),
                if (stream.isNotEmpty || batch.isNotEmpty)
                  Text(
                    '$stream${batch.isNotEmpty ? " • $batch" : ""}',
                    style: TextStyle(color: c.textMid, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                if (program.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(program,
                      style: TextStyle(color: c.textMid, fontSize: 12),
                      textAlign: TextAlign.center, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 16),
                // Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _quickBadge(Icons.school_rounded, "Student", c.violet),
                    const SizedBox(width: 10),
                    _quickBadge(Icons.check_circle_rounded, "Active", c.green),
                    const SizedBox(width: 10),
                    _quickBadge(Icons.shield_rounded, "Verified", c.cyan),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Photo helpers
  Widget _photoPlaceholder(ThemeProvider c) => Container(
    color: c.elevated,
    child: Center(
      child: SizedBox(
        width: 22, height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.violet),
      ),
    ),
  );

  Widget _photoFallback(ThemeProvider c) {
    final initials = (_studentName ?? widget.studentName)
        .trim().split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2).join().toUpperCase();
    return Container(
      color: c.violet.withOpacity(0.12),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials,
                style: TextStyle(color: c.violet, fontSize: 32, fontWeight: FontWeight.w900))
            : Icon(Icons.person_rounded, size: 44, color: c.violet),
      ),
    );
  }

  Widget _quickBadge(IconData icon, String label, Color color) {
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
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── INFO CARD ───────────────────────────────────────────────────────────
  Widget _infoCard(String title, IconData icon, Color color, List<Widget> rows, ThemeProvider c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
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
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: color, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, ThemeProvider c,
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
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: (color ?? c.textLow).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (color ?? c.textLow).withOpacity(0.2)),
              ),
              child: Icon(icon, size: 15, color: color ?? c.textMid),
            ),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 44),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontWeight: FontWeight.w600,
                        color: c.textMid, fontSize: 11, letterSpacing: 0.2)),
                const SizedBox(height: 3),
                Text(display,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasValue ? c.textHigh : c.textLow,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ROW BUILDERS ────────────────────────────────────────────────────────
  List<Widget> _academicRows(ThemeProvider c) => [
    _infoRow("Program Name", studentData?["current_academic"]?["program_name"] ?? "", c, icon: Icons.auto_stories_rounded, color: c.cyan),
    _infoRow("Department", studentData?["current_academic"]?["department_name"] ?? "", c, icon: Icons.account_balance_rounded, color: c.violet),
    _infoRow("Section", studentData?["current_academic"]?["section"] ?? "", c, icon: Icons.group_work_rounded, color: c.green),
    _infoRow("Program Type", studentData?["current_academic"]?["program_type"] ?? "", c, icon: Icons.category_rounded, color: c.amber),
    _infoRow("Admission Number", studentData?["admission_number"]?.toString() ?? "", c, icon: Icons.confirmation_num_rounded, color: c.violet),
    _infoRow("Admission Date", studentData?["admission_date"]?.split("T")[0] ?? "", c, icon: Icons.calendar_today_rounded, color: c.cyan),
  ];

  List<Widget> _personalRows(ThemeProvider c) => [
    _infoRow("Date of Birth", studentData?["personal_info"]?["dob"]?.split("T")[0] ?? "", c, icon: Icons.cake_rounded, color: c.pink),
    _infoRow("Gender", studentData?["personal_info"]?["gender"] ?? "", c, icon: Icons.person_outline_rounded, color: c.violet),
    _infoRow("Blood Group", studentData?["personal_info"]?["blood_group"] ?? "", c, icon: Icons.bloodtype_rounded, color: c.pink),
    _infoRow("Aadhar Number", studentData?["personal_info"]?["aadhar"] ?? "", c, icon: Icons.credit_card_rounded, color: c.cyan),
    _infoRow("Community", studentData?["personal_info"]?["community"] ?? "", c, icon: Icons.people_rounded, color: c.amber),
    _infoRow("Mother Tongue", studentData?["personal_info"]?["mother_tongue"] ?? "", c, icon: Icons.language_rounded, color: c.green),
  ];

  List<Widget> _familyRows(ThemeProvider c) => [
    _infoRow("Father's Name", studentData?["personal_info"]?["family"]?["father"]?["name"] ?? "", c, icon: Icons.person_2_rounded, color: c.cyan),
    _infoRow("Father's Occupation", studentData?["personal_info"]?["family"]?["father"]?["occupation"] ?? "", c, icon: Icons.work_rounded, color: c.amber),
    _infoRow("Father's Mobile", studentData?["personal_info"]?["family"]?["father"]?["mobile_no"] ?? "", c, icon: Icons.phone_rounded, color: c.green),
    _infoRow("Father's Income",
        studentData?["personal_info"]?["family"]?["father"]?["income"] != null
            ? "₹${studentData?["personal_info"]?["family"]?["father"]?["income"]}"
            : "",
        c, icon: Icons.attach_money_rounded, color: c.green),
    _infoRow("Mother's Name", studentData?["personal_info"]?["family"]?["mother"]?["name"] ?? "", c, icon: Icons.person_2_rounded, color: c.pink),
    _infoRow("Mother's Occupation", studentData?["personal_info"]?["family"]?["mother"]?["occupation"] ?? "", c, icon: Icons.work_rounded, color: c.amber),
    _infoRow("Mother's Mobile", studentData?["personal_info"]?["family"]?["mother"]?["mobile_no"] ?? "", c, icon: Icons.phone_rounded, color: c.green),
  ];

  List<Widget> _contactRows(ThemeProvider c) => [
    _infoRow("Email Address", studentData?["contact"]?["student_email"] ?? "", c, icon: Icons.email_rounded, color: c.pink),
    _infoRow("Mobile Number", studentData?["contact"]?["mobile_no"]?.toString() ?? "", c, icon: Icons.phone_iphone_rounded, color: c.green),
    _infoRow("Current Address", _buildAddressString(studentData?["contact"]?["address"]?["communication"]), c, icon: Icons.location_on_rounded, color: c.cyan),
  ];

  List<Widget> _prevAcademicRows(ThemeProvider c) {
    final info = studentData?["academic_info"];
    if (info == null || (info as List).isEmpty) return [];
    return [
      _infoRow("Qualification", info[0]["qualification"] ?? "", c, icon: Icons.book_rounded, color: c.violet),
      _infoRow("Institution", info[0]["institution"] ?? "", c, icon: Icons.account_balance_rounded, color: c.amber),
      _infoRow("Board/University", info[0]["board"] ?? "", c, icon: Icons.school_rounded, color: c.cyan),
      _infoRow("Percentage", info[0]["percentage"]?.toString() ?? "", c, icon: Icons.percent_rounded, color: c.green),
      _infoRow("UMIS Number", info[0]["umis"] ?? "", c, icon: Icons.numbers_rounded, color: c.pink),
    ];
  }

  List<Widget> _additionalRows(ThemeProvider c) => [
    _infoRow("Application Number", studentData?["application_no"]?.toString() ?? "", c, icon: Icons.numbers_rounded, color: c.cyan),
    _infoRow("Shift", studentData?["shift"] ?? "", c, icon: Icons.schedule_rounded, color: c.amber),
    _infoRow("Status", studentData?["status"] ?? "", c, icon: Icons.circle_rounded,
        color: studentData?["status"] == "Active" ? c.green : c.pink),
    _infoRow("Registration Date", studentData?["registration_date"]?.split("T")[0] ?? "", c, icon: Icons.date_range_rounded, color: c.violet),
  ];

  String _buildAddressString(Map<String, dynamic>? address) {
    if (address == null) return "";
    return [
      address["address_line1"],
      address["address_line2"],
      address["city"],
      address["state"],
      address["pincode"],
    ].where((p) => p != null && (p as String).isNotEmpty).join(", ");
  }

  // ─── LOADING / ERROR ─────────────────────────────────────────────────────
  Widget _buildLoadingState(ThemeProvider c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: c.violet.withOpacity(0.08 + _pulseCtrl.value * 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: c.violet.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                      strokeWidth: 2.5, color: c.violet,
                      backgroundColor: c.violet.withOpacity(0.1)),
                  Icon(Icons.person_rounded, size: 24, color: c.violet.withOpacity(0.6)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text("Loading Profile...",
              style: TextStyle(fontSize: 14, color: c.textMid, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text("Fetching your data", style: TextStyle(fontSize: 12, color: c.textLow)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: c.pink.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: c.pink.withOpacity(0.3)),
              ),
              child: Icon(Icons.error_outline_rounded, size: 44, color: c.pink),
            ),
            const SizedBox(height: 22),
            Text("Unable to Load Profile",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textHigh)),
            const SizedBox(height: 10),
            Text(errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMid, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Try Again", style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.violet.withOpacity(0.15),
                foregroundColor: c.violet,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: c.violet)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid Painter ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    const sp = 28.0;
    for (double x = 0; x <= size.width; x += sp)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y <= size.height; y += sp)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}