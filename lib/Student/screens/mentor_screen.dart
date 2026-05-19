import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Student/widgets/custom_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ─── MENTOR CHAT MESSAGE MODEL ───────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isStudent;
  final DateTime time;
  ChatMessage({required this.text, required this.isStudent, required this.time});
}

// ─── MENTOR SCREEN ────────────────────────────────────────────────────────────
class MentorScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;

  const MentorScreen({
    super.key,
    required this.rollNo,
    required this.studentName,
  });

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen>
    with TickerProviderStateMixin {
  // ── State ──
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<dynamic> _sessionInfo = [];
  List<dynamic> _staffInfo = [];
  int _totalSessions = 0;
  String? _studentName;
  int _tabIndex = 0; // 0=overview, 1=sessions, 2=chat

  // ── Chat ──
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _isMentorTyping = false;

  // ── Animations ──
  late AnimationController _appBarGlow;
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _appBarGlow = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _scanCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _stagger = List.generate(
      8,
      (i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(i * 0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    // seed chat with welcome
    _messages.add(ChatMessage(
      text: 'Hello! Feel free to ask me anything about your academics or goals.',
      isStudent: false,
      time: DateTime.now().subtract(const Duration(minutes: 30)),
    ));
    _loadStudentName();
    _fetchMentorData();
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _staggerCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _studentName = prefs.getString('studentName') ?? widget.studentName);
  }

  Future<void> _fetchMentorData() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final res = await http.get(
        Uri.parse('https://apierp.bhc.edu.in/api/staff/mentorship/get_student_session/${widget.rollNo}'),
        headers: {'Referer': 'http://117.232.64.75', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() {
            _totalSessions = data['data']['total_sessions'] ?? 0;
            _sessionInfo   = data['data']['session_info'] ?? [];
            _staffInfo     = data['data']['staff_info'] ?? [];
          });
        } else throw Exception('API returned success: false');
      }
    } catch (e) {
      setState(() { _hasError = true; _errorMessage = e.toString(); });
    } finally {
      setState(() => _isLoading = false);
      if (!_hasError && mounted) _staggerCtrl.forward();
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown Date';
    try {
      final s = date.toString();
      if (s.contains('T')) {
        final p = s.split('T')[0].split('-');
        if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
      }
      return s;
    } catch (_) { return date.toString(); }
  }

  // ─── SEND CHAT MESSAGE ────────────────────────────────────────────────────
  void _sendMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isStudent: true, time: DateTime.now()));
      _isMentorTyping = true;
    });
    _chatCtrl.clear();
    _scrollChat();
    // Simulate mentor reply
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isMentorTyping = false;
        _messages.add(ChatMessage(
          text: _autoReply(text),
          isStudent: false,
          time: DateTime.now(),
        ));
      });
      _scrollChat();
    });
  }

  String _autoReply(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('attendance')) return 'Please ensure you maintain at least 75% attendance to be eligible for exams.';
    if (lower.contains('exam') || lower.contains('marks')) return 'Focus on previous year papers and practice regularly. You can do it!';
    if (lower.contains('hello') || lower.contains('hi')) return 'Hello! How can I help you today?';
    return "Thank you for reaching out. I'll get back to you shortly. Please feel free to come during office hours.";
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ─── APPBAR ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ThemeProvider c) {
    final labels = ['Student Mentor', 'Sessions', 'Chat'];
    final subs   = ['MENTORSHIP PROGRAM', 'SESSION HISTORY', 'MENTOR CHAT'];
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.cyan.withOpacity(0.2 + _appBarGlow.value * 0.15))),
            boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.05 + _appBarGlow.value * 0.04), blurRadius: 20)],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Builder(builder: (ctx) => IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                    child: Icon(Icons.menu_rounded, color: c.textHigh, size: 18),
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                )),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labels[_tabIndex], style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(subs[_tabIndex], style: TextStyle(color: c.cyan.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ],
                ),
                const Spacer(),
                if (_tabIndex != 2) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _staffInfo.isNotEmpty ? c.green.withOpacity(0.1) : c.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _staffInfo.isNotEmpty ? c.green.withOpacity(0.3) : c.amber.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _staffInfo.isNotEmpty ? c.green : c.amber)),
                      const SizedBox(width: 5),
                      Text(_staffInfo.isNotEmpty ? 'ASSIGNED' : 'PENDING',
                        style: TextStyle(color: _staffInfo.isNotEmpty ? c.green : c.amber, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ]),
                  ),
                  IconButton(icon: Icon(Icons.refresh_rounded, color: c.textMid, size: 20), onPressed: _fetchMentorData),
                ] else ...[
                  // Chat header info
                  if (_staffInfo.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.green.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c.green,
                            boxShadow: [BoxShadow(color: c.green.withOpacity(0.6), blurRadius: 4)])),
                        const SizedBox(width: 5),
                        Text('ONLINE', style: TextStyle(color: c.green, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ]),
                    ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────────────────────
  Widget _buildBottomNav(ThemeProvider c) {
    final items = [
      (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Overview'),
      (Icons.timeline_rounded, Icons.timeline_outlined, 'Sessions'),
      (Icons.chat_rounded, Icons.chat_outlined, 'Chat'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _tabIndex = i; if (i == 2) _scrollChat(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(active ? items[i].$1 : items[i].$2,
                        color: active ? c.cyan : c.textMid, size: 22),
                    const SizedBox(height: 4),
                    Text(items[i].$3, style: TextStyle(
                        color: active ? c.cyan : c.textMid,
                        fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 16 : 0, height: 2,
                      decoration: BoxDecoration(color: c.cyan, borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── CHAT PAGE ────────────────────────────────────────────────────────────
  Widget _buildChatPage(ThemeProvider c) {
    final mentor = _staffInfo.isNotEmpty ? _staffInfo[0] : null;
    final initial = (mentor?['staff_name'] ?? 'M')[0].toUpperCase();
    return Column(
      children: [
        // Mentor info bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [c.cyan.withOpacity(0.3), c.cyan.withOpacity(0.1)]),
                  border: Border.all(color: c.cyan.withOpacity(0.4), width: 1.5),
                ),
                child: Center(child: Text(initial, style: TextStyle(color: c.cyan, fontSize: 18, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mentor?['staff_name'] ?? 'Your Mentor', style: TextStyle(color: c.textHigh, fontSize: 14, fontWeight: FontWeight.w800)),
                  Row(children: [
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.green,
                            boxShadow: [BoxShadow(color: c.green.withOpacity(0.6), blurRadius: 4)])),
                    Text('Online • ${mentor?['designation'] ?? 'Faculty'}',
                        style: TextStyle(color: c.textMid, fontSize: 11)),
                  ]),
                ]),
              ),
              // Call icon button
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.cyan.withOpacity(0.2)),
                ),
                child: Icon(Icons.call_rounded, color: c.cyan, size: 18),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isMentorTyping ? 1 : 0),
            itemBuilder: (_, i) {
              if (_isMentorTyping && i == _messages.length) {
                return _buildTypingIndicator(c);
              }
              return _buildMessageBubble(c, _messages[i]);
            },
          ),
        ),
        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.elevated, borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: _chatCtrl,
                    maxLines: 4, minLines: 1,
                    style: TextStyle(color: c.textHigh, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Message your mentor...',
                      hintStyle: TextStyle(color: c.textMid, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [c.cyan, c.cyan.withOpacity(0.7)],
                    ),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ThemeProvider c, ChatMessage msg) {
    final isMe = msg.isStudent;
    final timeStr = DateFormat('hh:mm a').format(msg.time);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [c.cyan.withOpacity(0.3), c.cyan.withOpacity(0.1)]),
                border: Border.all(color: c.cyan.withOpacity(0.3)),
              ),
              child: Center(child: Text(
                (_staffInfo.isNotEmpty ? _staffInfo[0]['staff_name'] : 'M')[0].toUpperCase(),
                style: TextStyle(color: c.cyan, fontSize: 12, fontWeight: FontWeight.w800),
              )),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? c.cyan.withOpacity(0.15) : c.elevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: Border.all(color: isMe ? c.cyan.withOpacity(0.25) : c.border),
                  ),
                  child: Text(msg.text, style: TextStyle(color: c.textHigh, fontSize: 13, height: 1.5)),
                ),
                const SizedBox(height: 4),
                Text(timeStr, style: TextStyle(color: c.textMid, fontSize: 10)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeProvider c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c.cyan.withOpacity(0.3), c.cyan.withOpacity(0.1)]),
              border: Border.all(color: c.cyan.withOpacity(0.3)),
            ),
            child: Center(child: Text(
              (_staffInfo.isNotEmpty ? _staffInfo[0]['staff_name'] : 'M')[0].toUpperCase(),
              style: TextStyle(color: c.cyan, fontSize: 12, fontWeight: FontWeight.w800),
            )),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.elevated, borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: c.border),
            ),
            child: _TypingDots(color: c.textMid),
          ),
        ],
      ),
    );
  }

  // ─── OVERVIEW PAGE ────────────────────────────────────────────────────────
  Widget _buildOverview(ThemeProvider c) {
    return RefreshIndicator(
      onRefresh: _fetchMentorData,
      color: c.cyan,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(children: [
          _animated(0, _buildHeroBanner(c)),
          const SizedBox(height: 16),
          if (_staffInfo.isNotEmpty) _animated(1, _buildMentorCard(c)),
          const SizedBox(height: 16),
          _animated(2, _buildSessionsSummary(c)),
        ]),
      ),
    );
  }

  Widget _animated(int i, Widget child) => FadeTransition(
    opacity: _stagger[i],
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_stagger[i]),
      child: child,
    ),
  );

  // ─── HERO BANNER ─────────────────────────────────────────────────────────
  Widget _buildHeroBanner(ThemeProvider c) {
    final completed = _sessionInfo.where((s) => (s['status'] as String? ?? '').toLowerCase() == 'completed').length;
    final pending   = _sessionInfo.where((s) => (s['status'] as String? ?? '').toLowerCase() == 'pending').length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c.bannerGradient),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.08), blurRadius: 30)],
      ),
      child: Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(20),
          child: CustomPaint(painter: _GridPainter(color: c.cyan.withOpacity(0.03)), size: const Size(double.infinity, 160))),
        AnimatedBuilder(animation: _scanCtrl, builder: (_, __) => Positioned(
          top: (_scanCtrl.value * 160 - 2).clamp(0, 156).toDouble(), left: 0, right: 0,
          child: Container(height: 2, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, c.cyan.withOpacity(0.35), Colors.transparent]))),
        )),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) => Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.green,
                        boxShadow: [BoxShadow(color: c.green.withOpacity(0.4 + _pulseCtrl.value * 0.3),
                            blurRadius: 8 + _pulseCtrl.value * 4)]),
                  )),
                  const SizedBox(width: 8),
                  Text('MENTORSHIP', style: TextStyle(color: c.cyan.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
                ]),
                const SizedBox(height: 8),
                Text(_studentName?.split(' ').first ?? 'Student',
                    style: TextStyle(color: c.textHigh, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 4),
                Text(_staffInfo.isNotEmpty ? 'Mentor Assigned' : 'No Mentor Yet',
                    style: TextStyle(color: c.textMid, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.cyan.withOpacity(0.25))),
                child: Icon(Icons.school_rounded, color: c.cyan, size: 26),
              ),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(c, Icons.assignment_rounded, '$_totalSessions Sessions', c.cyan),
              _chip(c, Icons.check_circle_rounded, '$completed Completed', c.green),
              _chip(c, Icons.pending_rounded, '$pending Pending', c.amber),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(ThemeProvider c, IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 11), const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );

  // ─── MENTOR CARD ─────────────────────────────────────────────────────────
  Widget _buildMentorCard(ThemeProvider c) {
    if (_staffInfo.isEmpty) return const SizedBox();
    final staff = _staffInfo[0];
    return Container(
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.cyan.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(children: [
        // Header
        _sectionHead(c, Icons.supervisor_account_rounded, 'Your Mentor', c.cyan),
        // Avatar + name
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.cyan.withOpacity(0.3), c.cyan.withOpacity(0.1)]),
                shape: BoxShape.circle, border: Border.all(color: c.cyan.withOpacity(0.4)),
              ),
              child: Center(child: Text((staff['staff_name'] ?? 'M')[0].toUpperCase(),
                  style: TextStyle(color: c.cyan, fontSize: 24, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(staff['staff_name'] ?? 'Not Available',
                  style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(staff['designation'] ?? 'Faculty', style: TextStyle(color: c.cyan, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        // Info rows
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(children: [
            _infoRow(c, Icons.business_center_rounded, staff['department_name'] ?? 'Not Available', c.violet),
            const SizedBox(height: 10),
            _infoRow(c, Icons.fingerprint_rounded, staff['staff_id'] ?? 'N/A', c.amber),
            if (staff['staff_email'] != null) ...[const SizedBox(height: 10), _infoRow(c, Icons.email_rounded, staff['staff_email']!, c.pink)],
          ]),
        ),
        // Chat CTA
        GestureDetector(
          onTap: () => setState(() => _tabIndex = 2),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.cyan.withOpacity(0.15), c.cyan.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.cyan.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: c.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.chat_rounded, color: c.cyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chat with Mentor', style: TextStyle(color: c.cyan, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Send a message to ${(staff['staff_name'] ?? 'your mentor').split(' ').first}',
                    style: TextStyle(color: c.textMid, fontSize: 11)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: c.cyan, size: 14),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionHead(ThemeProvider c, IconData icon, String title, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 12),
      Text(title, style: TextStyle(color: c.textHigh, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _infoRow(ThemeProvider c, IconData icon, String value, Color color) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 14),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(value, style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w500),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);

  // ─── SESSIONS SUMMARY ─────────────────────────────────────────────────────
  Widget _buildSessionsSummary(ThemeProvider c) {
    final completed = _sessionInfo.where((s) => (s['status'] as String? ?? '').toLowerCase() == 'completed').length;
    final pending   = _sessionInfo.where((s) => (s['status'] as String? ?? '').toLowerCase() == 'pending').length;
    return Container(
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.green.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: c.green.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(children: [
        _sectionHead(c, Icons.bar_chart_rounded, 'Session Overview', c.green),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _statTile(c, '$_totalSessions', 'Total', c.cyan, Icons.assignment_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _statTile(c, '$completed', 'Done', c.green, Icons.check_circle_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _statTile(c, '$pending', 'Pending', c.amber, Icons.pending_rounded)),
            ]),
            if (_totalSessions > 0) ...[
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Completion Rate', style: TextStyle(color: c.textMid, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${((completed / _totalSessions) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: c.green, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completed / _totalSessions,
                  backgroundColor: c.border, valueColor: AlwaysStoppedAnimation(c.green), minHeight: 6)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _statTile(ThemeProvider c, String value, String label, Color color, IconData icon) =>
    Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 18), const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: c.textLow, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );

  // ─── SESSIONS PAGE ────────────────────────────────────────────────────────
  Widget _buildSessionsPage(ThemeProvider c) {
    if (_sessionInfo.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.amber.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.event_note_outlined, color: c.amber, size: 40)),
          const SizedBox(height: 16),
          Text('No Sessions Yet', style: TextStyle(color: c.textHigh, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Sessions will appear here once conducted.', textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 12)),
        ]),
      ));
    }
    return RefreshIndicator(
      onRefresh: _fetchMentorData, color: c.cyan,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Container(
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border)),
          child: Column(children: [
            _sectionHead(c, Icons.timeline_rounded, 'Mentoring Sessions (${_sessionInfo.length})', c.cyan),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: _sessionInfo.reversed.map((s) => _sessionItem(c, s)).toList()),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sessionItem(ThemeProvider c, Map<String, dynamic> session) {
    final date = _formatDate(session['session_date']);
    final status = session['status'] ?? 'unknown';
    final color = status.toLowerCase() == 'completed' ? c.green : c.amber;
    final details = (session['details_matters'] != null && session['details_matters'].isNotEmpty)
        ? session['details_matters'][0] : {};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: c.textMid, iconColor: color,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(status.toLowerCase() == 'completed' ? Icons.check_circle_rounded : Icons.pending_rounded, color: color, size: 18),
          ),
          title: Text('Session • $date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textHigh)),
          subtitle: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (details['attendance']?.isNotEmpty == true) _detail(c, 'Attendance', details['attendance'], c.green),
                if (details['academicPerformance']?.isNotEmpty == true) _detail(c, 'Academic Performance', details['academicPerformance'], c.cyan),
                if (details['personalGoals']?.isNotEmpty == true) _detail(c, 'Personal Goals', details['personalGoals'], c.violet),
                if (details['professionalGoals']?.isNotEmpty == true) _detail(c, 'Professional Goals', details['professionalGoals'], c.amber),
                if (session['mentor_feedback']?.isNotEmpty == true) _detail(c, 'Mentor Feedback', session['mentor_feedback'], c.pink),
                if (session['positive_traits']?.isNotEmpty == true) _detail(c, 'Positive Traits', session['positive_traits'], c.green),
                if (session['corrective_measures']?.isNotEmpty == true) _detail(c, 'Corrective Measures', session['corrective_measures'], c.amber),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(ThemeProvider c, String label, String value, Color color) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
          child: Text(value, style: TextStyle(fontSize: 12, color: c.textMid)),
        ),
      ]),
    );

  // ─── LOADING / ERROR ──────────────────────────────────────────────────────
  Widget _buildLoading(ThemeProvider c) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(width: 40, height: 40,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.cyan, backgroundColor: c.cyan.withOpacity(0.1))),
    const SizedBox(height: 16),
    Text('Loading mentor data...', style: TextStyle(color: c.textMid, fontSize: 14)),
  ]));

  Widget _buildError(ThemeProvider c) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.pink.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.error_outline_rounded, color: c.pink, size: 40)),
      const SizedBox(height: 16),
      Text('Failed to Load', style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 13)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _fetchMentorData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(color: c.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cyan.withOpacity(0.3))),
          child: Text('Try Again', style: TextStyle(color: c.cyan, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  ));

  Widget _buildNoMentor(ThemeProvider c) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.amber.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.school_outlined, size: 50, color: c.amber)),
      const SizedBox(height: 20),
      Text('No Mentor Assigned', style: TextStyle(color: c.textHigh, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text('No sessions found for your roll number.', textAlign: TextAlign.center,
          style: TextStyle(color: c.textMid, fontSize: 13)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _fetchMentorData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(color: c.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.amber.withOpacity(0.3))),
          child: Text('Refresh', style: TextStyle(color: c.amber, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  ));

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    Widget body;
    if (_isLoading) {
      body = _buildLoading(c);
    } else if (_hasError) {
      body = _buildError(c);
    } else if (_totalSessions == 0 && _staffInfo.isEmpty) {
      body = _buildNoMentor(c);
    } else {
      body = IndexedStack(
        index: _tabIndex,
        children: [
          _buildOverview(c),
          _buildSessionsPage(c),
          _buildChatPage(c),
        ],
      );
    }
    return Scaffold(
      backgroundColor: c.bg,
      drawer: CustomDrawer(rollNo: widget.rollNo, studentName: _studentName ?? widget.studentName, currentRoute: '/mentor'),
      appBar: _buildAppBar(c),
      body: body,
      bottomNavigationBar: (!_isLoading && !_hasError && !(_totalSessions == 0 && _staffInfo.isEmpty))
          ? _buildBottomNav(c)
          : null,
    );
  }
}

// ─── TYPING DOTS WIDGET ───────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});
  @override State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
        final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
        final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.3, 1.0);
        return Container(
          width: 6, height: 6,
          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(opacity)),
        );
      })),
    );
  }
}

// ─── GRID PAINTER ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y <= size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}