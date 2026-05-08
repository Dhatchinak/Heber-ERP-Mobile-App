// my_bookings_screen.dart — Complete redesign matching Staff ERP design system

import 'dart:convert';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with TickerProviderStateMixin {
  // ── STATE ────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  String? _staffId;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  String _tab = 'All';
  String _search = '';

  final _searchCtrl = TextEditingController();

  // ── Animations ───────────────────────────────────────────
  late AnimationController _appBarGlow;
  late AnimationController _pageEnterCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;
  late AnimationController _fabCtrl;

  final ScrollController _scrollController = ScrollController();

  bool get _isHod {
    final auth = context.read<AuthProvider>();
    return auth.userRole == UserRole.hod;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _staffId = auth.userData?['staff_id']?.toString();
      _fetch();
    });

    _pageEnterCtrl.forward();
    _staggerCtrl.forward();
    _fabCtrl.forward();
  }

  void _initAnimations() {
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pageEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _stagger = List.generate(
      5,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _pageFade = CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pageEnterCtrl.dispose();
    _staggerCtrl.dispose();
    _fabCtrl.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _stagger[i],
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(_stagger[i]),
          child: child,
        ),
      );

  // ── API ──────────────────────────────────────────────────
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_staffId == null || _staffId!.isEmpty) {
        setState(() {
          _error = 'Staff ID not found. Please login again.';
          _loading = false;
        });
        return;
      }

      final uri = Uri.parse(
        'https://apierp.bhc.edu.in/api/office/hall/booking/your_booking/$_staffId'
      );
      final res = await http.get(uri, headers: {
        'Referer': 'http://117.232.64.75',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true) {
          _all = body['data'] ?? [];
        } else {
          _error = body['message'] ?? 'Something went wrong.';
        }
      } else {
        _error = 'Server error: ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Could not connect. Check your internet.';
    }

    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    final now = DateTime.now();
    _filtered = _all.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      final to = _parseDate(b['to']);

      // Tab filter
      if (_tab == 'Upcoming') {
        if (to != null && to.isBefore(now)) return false;
        if (status == 'cancelled' || status == 'rejected') return false;
      } else if (_tab == 'Completed') {
        if (to == null || to.isAfter(now)) return false;
      } else if (_tab == 'Cancelled') {
        if (status != 'cancelled' && status != 'rejected') return false;
      }

      // Search filter
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final ev = (b['eventName'] ?? '').toString().toLowerCase();
        final dp = (b['departmentName'] ?? '').toString().toLowerCase();
        return ev.contains(q) || dp.contains(q);
      }
      return true;
    }).toList();
  }

  void _onTabChange(String tab) {
    setState(() => _tab = tab);
    _applyFilter();
  }

  void _onSearch(String v) {
    setState(() => _search = v);
    _applyFilter();
  }

  // ── HELPERS ──────────────────────────────────────────────
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(dynamic v) {
    final d = _parseDate(v);
    return d == null ? 'N/A' : DateFormat('dd MMM yyyy').format(d);
  }

  String _fmtTime(dynamic v) {
    final d = _parseDate(v);
    return d == null ? 'N/A' : DateFormat('hh:mm a').format(d);
  }

  String _fmtDateTime(dynamic v) {
    final d = _parseDate(v);
    return d == null ? 'N/A' : DateFormat('dd MMM yyyy • hh:mm a').format(d);
  }

  Color _statusColor(StaffThemeProvider theme, String s) {
    switch (s.toLowerCase()) {
      case 'approved': return theme.green;
      case 'pending': return theme.amber;
      case 'rejected':
      case 'cancelled': return theme.error;
      case 'completed': return theme.cyan;
      default: return theme.textLow;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'approved': return Icons.check_circle_rounded;
      case 'pending': return Icons.schedule_rounded;
      case 'rejected':
      case 'cancelled': return Icons.cancel_rounded;
      case 'completed': return Icons.task_alt_rounded;
      default: return Icons.help_rounded;
    }
  }

  // ─── FUTURISTIC APP BAR ───────────────────────────────────
  PreferredSizeWidget _buildAppBar(StaffThemeProvider theme) {
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
                  color: theme.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04),
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
                          child: Icon(Icons.list_alt_rounded,
                              color: theme.cyan, size: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "My Bookings",
                          style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Hall & room reservations",
                          style: TextStyle(
                            color: theme.cyan.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.cyan,
                            boxShadow: [
                              BoxShadow(
                                  color: theme.cyan.withOpacity(0.6), blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "${_filtered.length}",
                          style: TextStyle(
                            color: theme.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        color: theme.textMid, size: 20),
                    onPressed: _fetch,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── SEARCH BAR ───────────────────────────────────────────
  Widget _buildSearchBar(StaffThemeProvider theme) {
    return _animated(
      0,
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: TextStyle(fontSize: 13, color: theme.textHigh),
          decoration: InputDecoration(
            hintText: 'Search by event or department…',
            hintStyle: TextStyle(fontSize: 13, color: theme.textLow),
            prefixIcon: Icon(Icons.search_rounded, color: theme.cyan, size: 18),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textMid, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  // ─── TABS ─────────────────────────────────────────────────
  Widget _buildTabs(StaffThemeProvider theme) {
    final tabs = ['All', 'Upcoming', 'Completed', 'Cancelled'];
    return _animated(
      1,
      Container(
        margin: const EdgeInsets.only(top: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: tabs.map((t) {
              final active = _tab == t;
              final color = active ? theme.cyan : theme.textMid;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _onTabChange(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(colors: [theme.cyan, theme.violet])
                          : null,
                      color: active ? null : theme.elevated,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: active ? Colors.transparent : theme.border,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: theme.cyan.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        if (t == 'All' && _filtered.length > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: active ? Colors.white.withOpacity(0.2) : theme.cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_all.length}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : theme.cyan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : theme.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── STATS ROW ───────────────────────────────────────────
  Widget _buildStatsRow(StaffThemeProvider theme) {
    final total = _filtered.length;
    final upcoming = _filtered.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      final to = _parseDate(b['to']);
      return status != 'cancelled' && status != 'rejected' && (to == null || to.isAfter(DateTime.now()));
    }).length;
    final completed = _filtered.where((b) {
      final to = _parseDate(b['to']);
      return to != null && to.isBefore(DateTime.now());
    }).length;

    return _animated(
      2,
      Row(
        children: [
          Expanded(
            child: _statCard(theme, 'Total', total.toString(), Icons.event_note_rounded, theme.cyan),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(theme, 'Upcoming', upcoming.toString(), Icons.upcoming_rounded, theme.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(theme, 'Completed', completed.toString(), Icons.check_circle_rounded, theme.violet),
          ),
        ],
      ),
    );
  }

  Widget _statCard(StaffThemeProvider theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textHigh),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.textMid),
          ),
        ],
      ),
    );
  }

  // ─── BOOKING CARD ─────────────────────────────────────────
  Widget _buildBookingCard(StaffThemeProvider theme, dynamic b, int index) {
    final status = (b['status'] ?? 'pending').toString();
    final statusColor = _statusColor(theme, status);
    final statusIcon = _statusIcon(status);
    final isHall = b['bookingType'] == 'Hall';
    final fromDate = _parseDate(b['from']);
    final isUpcoming = fromDate != null && fromDate.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(color: theme.cyan.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goDetails(theme, b),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isHall ? [theme.cyan, theme.violet] : [theme.green, theme.cyan],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isHall ? Icons.meeting_room_rounded : Icons.bed_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            isHall ? 'HALL' : 'ROOM',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isUpcoming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 10, color: theme.green),
                            const SizedBox(width: 3),
                            Text('UPCOMING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: theme.green)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Event Name
                Text(
                  b['eventName'] ?? 'Untitled Event',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: theme.textHigh),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Department
                if (b['departmentName'] != null && b['departmentName'].toString().isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 12, color: theme.textLow),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          b['departmentName'],
                          style: TextStyle(fontSize: 11, color: theme.textMid),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),

                // Date range
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FROM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: theme.cyan, letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(_fmtDate(b['from']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textHigh)),
                            Text(_fmtTime(b['from']), style: TextStyle(fontSize: 11, color: theme.textLow)),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: theme.textLow),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: theme.amber, letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(_fmtDate(b['to']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textHigh)),
                            Text(_fmtTime(b['to']), style: TextStyle(fontSize: 11, color: theme.textLow)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Status row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 18, color: theme.textLow),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BODY ─────────────────────────────────────────────────
  Widget _buildBody(StaffThemeProvider theme) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.cyan),
              ),
            ),
            const SizedBox(height: 16),
            Text('Loading bookings...', style: TextStyle(fontSize: 14, color: theme.textMid)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded, size: 48, color: theme.error),
              ),
              const SizedBox(height: 20),
              Text(
                'Connection Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.textHigh),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: theme.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _fetch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.3), blurRadius: 10)],
                  ),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cyan.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _search.isNotEmpty ? Icons.search_off_rounded : Icons.event_busy_rounded,
                size: 56,
                color: theme.textLow,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _search.isNotEmpty ? 'No results for "$_search"' : 'No bookings yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textMid),
            ),
            const SizedBox(height: 6),
            Text(
              _search.isNotEmpty ? 'Try a different search term' : 'Your bookings will appear here',
              style: TextStyle(fontSize: 12, color: theme.textLow),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: theme.cyan,
      backgroundColor: theme.surface,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _buildBookingCard(theme, _filtered[i], i),
      ),
    );
  }

  // ─── NAVIGATION ───────────────────────────────────────────
  void _goDetails(StaffThemeProvider theme, dynamic booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(booking: booking),
      ),
    );
  }

  // ─── MAIN BUILD ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<StaffThemeProvider>();

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      drawer: AppDrawer(
        isHod: _isHod,
        currentRoute: '/my-bookings',
      ),
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: Column(
            children: [
              _buildSearchBar(theme),
              _buildTabs(theme),
              const SizedBox(height: 12),
              _animated(3, _buildStatsRow(theme)),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(theme)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKING DETAILS SCREEN — Complete with proper app bar
// ═══════════════════════════════════════════════════════════════════════════

class BookingDetailsScreen extends StatefulWidget {
  final dynamic booking;
  const BookingDetailsScreen({super.key, required this.booking});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _appBarGlow;
  late AnimationController _pageEnterCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pageEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pageFade = CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic));

    _pageEnterCtrl.forward();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pageEnterCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _fmtDateTime(dynamic v) {
    final d = _parseDate(v);
    return d == null ? 'N/A' : DateFormat('dd MMM yyyy • hh:mm a').format(d);
  }

  Color _statusColor(StaffThemeProvider theme, String s) {
    switch (s.toLowerCase()) {
      case 'approved': return theme.green;
      case 'pending': return theme.amber;
      case 'rejected':
      case 'cancelled': return theme.error;
      case 'completed': return theme.cyan;
      default: return theme.textLow;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'approved': return Icons.check_circle_rounded;
      case 'pending': return Icons.schedule_rounded;
      case 'rejected':
      case 'cancelled': return Icons.cancel_rounded;
      case 'completed': return Icons.task_alt_rounded;
      default: return Icons.help_rounded;
    }
  }

  // ─── FUTURISTIC APP BAR ───────────────────────────────────
  PreferredSizeWidget _buildAppBar(StaffThemeProvider theme) {
    final booking = widget.booking;
    final status = (booking['status'] ?? 'pending').toString();
    final statusColor = _statusColor(theme, status);

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
                  color: theme.cyan.withOpacity(0.06 + _appBarGlow.value * 0.04),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: theme.textHigh, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  
                  // Logo icon
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
                          child: Icon(Icons.receipt_long_rounded,
                              color: theme.cyan, size: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  // Title section
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Booking Details",
                          style: TextStyle(
                            color: theme.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Ref: ${booking['_id']?.toString().substring(0, 8) ?? 'N/A'}",
                          style: TextStyle(
                            color: theme.cyan.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                            boxShadow: [
                              BoxShadow(
                                  color: statusColor.withOpacity(0.6),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<StaffThemeProvider>();
    final b = widget.booking;
    final isHall = b['bookingType'] == 'Hall';
    final status = (b['status'] ?? 'pending').toString();
    final statusColor = _statusColor(theme, status);

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),  // ← Only passing theme
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero section
                _buildHeroSection(theme, b, isHall, statusColor),
                const SizedBox(height: 20),

                // Date & Time
                _buildInfoCard(
                  theme,
                  icon: Icons.calendar_month_rounded,
                  title: 'Date & Time',
                  color: theme.cyan,
                  children: [
                    _infoRow(theme, 'From', _fmtDateTime(b['from']), Icons.play_arrow_rounded, theme.green),
                    const SizedBox(height: 12),
                    _infoRow(theme, 'To', _fmtDateTime(b['to']), Icons.stop_rounded, theme.amber),
                  ],
                ),
                const SizedBox(height: 16),

                // In-charge Details
                _buildInfoCard(
                  theme,
                  icon: Icons.badge_rounded,
                  title: 'In-charge Details',
                  color: theme.violet,
                  children: [
                    _infoRow(theme, 'Name', b['incharge'] ?? 'N/A', Icons.person_rounded, theme.cyan),
                    const SizedBox(height: 12),
                    _infoRow(theme, 'Contact', b['contactNumber'] ?? 'N/A', Icons.phone_rounded, theme.green),
                    if (b['email'] != null) ...[
                      const SizedBox(height: 12),
                      _infoRow(theme, 'Email', b['email'], Icons.email_rounded, theme.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Requirements
                if (_hasRequirements(b))
                  _buildInfoCard(
                    theme,
                    icon: Icons.checklist_rounded,
                    title: 'Requirements',
                    color: theme.pink,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (b['participants'] != null)
                          _reqChip(theme, Icons.people_rounded, '${b['participants']} Participants'),
                        if ((b['mikes'] ?? 0) > 0)
                          _reqChip(theme, Icons.mic_rounded, '${b['mikes']} Mikes'),
                        if ((b['chairs'] ?? 0) > 0)
                          _reqChip(theme, Icons.chair_rounded, '${b['chairs']} Chairs'),
                        if (b['otherRequirements']?.isNotEmpty == true)
                          _reqChip(theme, Icons.more_horiz_rounded, b['otherRequirements']),
                      ]),
                    ],
                  ),

                // Description
                if (b['description']?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    theme,
                    icon: Icons.notes_rounded,
                    title: 'Description',
                    color: theme.cyanDim,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.elevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border),
                        ),
                        child: Text(
                          b['description'],
                          style: TextStyle(fontSize: 13, color: theme.textHigh, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],

                // Action buttons for pending
                if (status.toLowerCase() == 'pending') ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.edit_rounded, size: 16, color: theme.amber),
                          label: const Text('Edit Request'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.amber,
                            side: BorderSide(color: theme.amber),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showCancelDialog(theme),
                          icon: Icon(Icons.cancel_rounded, size: 16, color: Colors.white),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.error,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HERO SECTION ───────────────────────────────────────────
  Widget _buildHeroSection(
    StaffThemeProvider theme,
    dynamic b,
    bool isHall,
    Color statusColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isHall ? Icons.meeting_room_rounded : Icons.bed_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        isHall ? 'HALL BOOKING' : 'ROOM BOOKING',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  b['eventName'] ?? 'Untitled Event',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textHigh,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (b['departmentName'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    b['departmentName'],
                    style: TextStyle(fontSize: 12, color: theme.textMid),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isHall ? theme.cyan : theme.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (isHall ? theme.cyan : theme.green).withOpacity(0.25)),
            ),
            child: Icon(
              isHall ? Icons.meeting_room_rounded : Icons.bed_rounded,
              color: isHall ? theme.cyan : theme.green,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // ─── INFO CARD ──────────────────────────────────────────────
  Widget _buildInfoCard(
    StaffThemeProvider theme, {
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
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
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
        ],
      ),
    );
  }

  // ─── INFO ROW ───────────────────────────────────────────────
  Widget _infoRow(StaffThemeProvider theme, String label, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: theme.textLow)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textHigh)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── REQUIREMENT CHIP ───────────────────────────────────────
  Widget _reqChip(StaffThemeProvider theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.cyan),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.textHigh)),
        ],
      ),
    );
  }

  bool _hasRequirements(dynamic b) {
    return b['participants'] != null ||
        (b['mikes'] ?? 0) > 0 ||
        (b['chairs'] ?? 0) > 0 ||
        (b['otherRequirements']?.isNotEmpty == true);
  }

  void _showCancelDialog(StaffThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: theme.error, size: 24),
            const SizedBox(width: 8),
            Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.w700, color: theme.textHigh)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(color: theme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back', style: TextStyle(color: theme.textMid)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cancellation request submitted'),
                  backgroundColor: theme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}


IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'approved': return Icons.check_circle_rounded;
    case 'pending': return Icons.schedule_rounded;
    case 'rejected':
    case 'cancelled': return Icons.cancel_rounded;
    case 'completed': return Icons.task_alt_rounded;
    default: return Icons.help_rounded;
  }
}

// // IconData _statusIcon(String status) {
//   switch (status.toLowerCase()) {
//     case 'approved': return Icons.check_circle_rounded;
//     case 'pending': return Icons.schedule_rounded;
//     case 'rejected':
//     case 'cancelled': return Icons.cancel_rounded;
//     case 'completed': return Icons.task_alt_rounded;
//     default: return Icons.help_rounded;
//   }
// }