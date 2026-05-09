import 'dart:async';
import 'dart:convert';
import 'package:bhc_erp/Staff/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import '../theme_provider.dart';

class EnhancedPublicationsScreen extends StatefulWidget {
  const EnhancedPublicationsScreen({super.key});

  @override
  State<EnhancedPublicationsScreen> createState() =>
      _EnhancedPublicationsScreenState();
}

class _EnhancedPublicationsScreenState extends State<EnhancedPublicationsScreen>
    with TickerProviderStateMixin {
  late List<_PubType> _pubTypes;

  final List<String> _levelOptions = [
    'International',
    'National',
    'Regional',
    'Institutional',
    'State'
  ];
  final List<String> _indexingOptions = [
    'Scopus',
    'Web of Science',
    'UGC Care',
    'Google Scholar',
    'Others'
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  int _selectedTypeIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAddForm = false;
  Map<String, dynamic> _publicationsData = {};
  String _searchQuery = '';
  double _loadingProgress = 0.0;
  List<Map<String, dynamic>> _allStaff = [];

  bool _isSearchingPapers = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  final TextEditingController _paperSearchController = TextEditingController();
  Map<String, dynamic>? _selectedPaper;

  final Map<String, GlobalKey<FormState>> _formKeys = {};
  final Map<String, Map<String, TextEditingController>> _formControllers = {};
  final Map<String, List<String>> _selectedAuthors = {};
  final Map<String, List<String>> _selectedCoAuthors = {};
  final Map<String, List<String>> _selectedInventors = {};

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _appBarGlow;
  late AnimationController _pageEnterCtrl;
  late AnimationController _tabCtrl;
  late AnimationController _fabCtrl;

  late Animation<double> _pageEnterFade;
  late Animation<Offset> _pageEnterSlide;
  late Animation<double> _tabFade;
  late Animation<Offset> _tabSlide;
  late Animation<double> _fabScale;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _buildPubTypes();
    _initAnimations();
    _initializeForms();
    _loadAllData();
  }

  void _buildPubTypes() {
    _pubTypes = [
      _PubType('Journal Articles', 'journal_articles', Icons.article_outlined),
      _PubType('Conference Papers', 'conference_papers', Icons.groups_outlined),
      _PubType('Book Chapters', 'book_chapters', Icons.menu_book_outlined),
      _PubType('Books Authored', 'books_authored', Icons.book_outlined),
      _PubType('Edited Volumes', 'edited_volume',
          Icons.collections_bookmark_outlined),
      _PubType('Patents', 'patent', Icons.badge_outlined),
    ];
  }

  void _initAnimations() {
    _appBarGlow =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _pageEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _tabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _pageEnterFade =
        CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOut);
    _pageEnterSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _pageEnterCtrl, curve: Curves.easeOutCubic));
    _tabFade = CurvedAnimation(parent: _tabCtrl, curve: Curves.easeOut);
    _tabSlide = Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _tabCtrl, curve: Curves.easeOutCubic));
    _fabScale = CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut);

    _pageEnterCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _tabCtrl.forward();
    });
  }

  void _buildCardAnimations(int count) {
    for (final c in _cardControllers) {
      c.stop();
      c.dispose();
    }
    _cardControllers.clear();
    _cardFades.clear();
    _cardSlides.clear();

    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 400));
      _cardControllers.add(ctrl);
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
              begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
    }

    for (int i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 55), () {
        if (mounted && i < _cardControllers.length)
          _cardControllers[i].forward();
      });
    }
  }

  void _animateTabSwitch() {
    _tabCtrl.reset();
    _tabCtrl.forward();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      final pubs =
          (_publicationsData[_pubTypes[_selectedTypeIndex].apiKey] as List?) ??
              [];
      _buildCardAnimations(pubs.length);
    });
  }

  @override
  void dispose() {
    _appBarGlow.dispose();
    _pageEnterCtrl.dispose();
    _tabCtrl.dispose();
    _fabCtrl.dispose();
    for (final c in _cardControllers) c.dispose();
    _scrollController.dispose();
    _paperSearchController.dispose();
    _searchDebounce?.cancel();
    for (var m in _formControllers.values) {
      for (var c in m.values) c.dispose();
    }
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadingProgress = 0; });
    try {
      // Run both in parallel — eliminates sequential 3–5s wait
      await Future.wait([_loadPublications(), _loadAllStaff()]);
      if (!mounted) return;
      setState(() => _loadingProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      final pubs = (_publicationsData[_pubTypes[_selectedTypeIndex].apiKey] as List?) ?? [];
      _buildCardAnimations(pubs.length);
      _fabCtrl.forward();
      setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Failed to load data', isError: true);
    }
  }

  Future<void> _loadPublications() async {
    final staffId = context.read<AuthProvider>().userData?['staff_id'];
    if (staffId == null) return;
    final res = await http.get(
      Uri.parse('https://apierp.bhc.edu.in/api/staff/publications/$staffId'),
      headers: {
        'Referer': 'http://117.232.64.75',
        'Accept': 'application/json'
      },
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['success'] == true && mounted) {
        setState(() => _publicationsData = data['data'] ?? {});
      }
    }
  }

  Future<void> _loadAllStaff() async {
    final res = await http.get(
      Uri.parse('http://apierp.bhc.edu.in/api/staff/'),
      headers: {
        'Referer': 'http://117.232.64.75',
        'Accept': 'application/json'
      },
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data is List && mounted) {
        setState(() {
          _allStaff = data
              .whereType<Map<String, dynamic>>()
              .where((s) => (s['name'] ?? '').toString().isNotEmpty)
              .map<Map<String, dynamic>>((s) => {
                    'staff_id': s['staff_id']?.toString().trim() ?? '',
                    'name': s['name']?.toString().trim() ?? '',
                    'department_name':
                        s['department_name']?.toString().trim() ?? '',
                    'designation': s['designation']?.toString().trim() ?? '',
                  })
              .toList();
        });
      }
    }
  }

  Future<void> _searchPapers(String q) async {
    if (q.length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() => _isSearchingPapers = true);
    try {
      final res = await http
          .get(Uri.parse('https://api.crossref.org/works?query=$q&rows=20'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final items = json.decode(res.body)['message']['items'] as List;
        if (mounted)
          setState(() {
            _searchResults = items
                .map<Map<String, dynamic>>((item) => {
                      'title': (item['title'] as List?)?.isNotEmpty == true
                          ? item['title'][0]
                          : 'Unknown',
                      'authors': ((item['author'] as List?) ?? [])
                          .map((a) =>
                              '${a['given'] ?? ''} ${a['family'] ?? ''}'.trim())
                          .toList(),
                      'year': item['published-print']?['date-parts']?[0]?[0]
                              ?.toString() ??
                          item['published-online']?['date-parts']?[0]?[0]
                              ?.toString() ??
                          '',
                      'journal':
                          (item['container-title'] as List?)?.isNotEmpty == true
                              ? item['container-title'][0]
                              : '',
                      'doi': item['DOI'] ?? '',
                      'publisher': item['publisher'] ?? '',
                      'volume': item['volume']?.toString() ?? '',
                      'issue': item['issue']?.toString() ?? '',
                      'pages': item['page']?.toString() ?? '',
                    })
                .toList();
            _isSearchingPapers = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingPapers = false);
    }
  }

  Future<void> _addPublication() async {
    final type = _pubTypes[_selectedTypeIndex];
    if (!(_formKeys[type.apiKey]?.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      final staffId = context.read<AuthProvider>().userData?['staff_id'];
      if (staffId == null) throw Exception();
      final body = <String, dynamic>{};
      _formControllers[type.apiKey]!.forEach((k, c) {
        if (c.text.isNotEmpty) body[k] = c.text;
      });
      if (type.apiKey == 'patent') {
        body['inventors'] = _selectedInventors[type.apiKey] ?? [];
      } else {
        body['authors'] = _selectedAuthors[type.apiKey] ?? [];
        body['co_authors'] = _selectedCoAuthors[type.apiKey] ?? [];
      }
      final res = await http
          .post(
            Uri.parse(
                'https://apierp.bhc.edu.in/api/staff/publications/$staffId/${type.apiKey}'),
            headers: {
              'Referer': 'http://117.232.64.75',
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));
      if ((res.statusCode == 200 || res.statusCode == 201) &&
          json.decode(res.body)['success'] == true) {
        _clearForm();
        await _loadAllData();
        if (mounted)
          setState(() {
            _showAddForm = false;
            _isSubmitting = false;
          });
        _snack('${type.name} added!');
      }
    } catch (_) {
      _snack('Failed to add publication', isError: true);
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deletePublication(String id) async {
    final theme = context.read<StaffThemeProvider>();
    final type = _pubTypes[_selectedTypeIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(theme: theme, typeName: type.name),
    );
    if (confirmed != true) return;
    try {
      final staffId = context.read<AuthProvider>().userData?['staff_id'];
      final res = await http.delete(
        Uri.parse(
            'https://apierp.bhc.edu.in/api/staff/publications/$staffId/${type.apiKey}/$id'),
        headers: {
          'Referer': 'http://117.232.64.75',
          'Accept': 'application/json'
        },
      );
      if (res.statusCode == 200) {
        await _loadPublications();
        _snack('Deleted');
      }
    } catch (_) {
      _snack('Delete failed', isError: true);
    }
  }

  void _clearForm() {
    final type = _pubTypes[_selectedTypeIndex];
    _formControllers[type.apiKey]?.values.forEach((c) => c.clear());
    setState(() {
      _selectedAuthors[type.apiKey]?.clear();
      _selectedCoAuthors[type.apiKey]?.clear();
      _selectedInventors[type.apiKey]?.clear();
      _selectedPaper = null;
    });
  }

  void _fillFromPaper() {
    if (_selectedPaper == null) return;
    final type = _pubTypes[_selectedTypeIndex];
    final c = _formControllers[type.apiKey]!;
    c['title']?.text = _selectedPaper!['title'] ?? '';
    c['year']?.text = _selectedPaper!['year'] ?? '';
    switch (type.apiKey) {
      case 'journal_articles':
        c['journal_name']?.text = _selectedPaper!['journal'] ?? '';
        c['doi']?.text = _selectedPaper!['doi'] ?? '';
        c['volume']?.text = _selectedPaper!['volume'] ?? '';
        c['issue']?.text = _selectedPaper!['issue'] ?? '';
        c['pages']?.text = _selectedPaper!['pages'] ?? '';
        break;
      case 'conference_papers':
        c['conference_name']?.text = _selectedPaper!['journal'] ?? '';
        c['publisher']?.text = _selectedPaper!['publisher'] ?? '';
        break;
      case 'book_chapters':
        c['book_title']?.text = _selectedPaper!['journal'] ?? '';
        c['publisher']?.text = _selectedPaper!['publisher'] ?? '';
        break;
      default:
        c['publisher']?.text = _selectedPaper!['publisher'] ?? '';
    }
    _snack('Paper imported!');
  }

  void _snack(String msg, {bool isError = false}) {
    final theme = context.read<StaffThemeProvider>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? theme.error : theme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _initializeForms() {
    final keys = {
      'journal_articles': [
        'title',
        'year',
        'level',
        'journal_name',
        'issn',
        'volume',
        'issue',
        'pages',
        'doi',
        'impact_factor',
        'citation_count',
        'author_position',
        'link',
        'indexing'
      ],
      'conference_papers': [
        'title',
        'year',
        'level',
        'conference_name',
        'isbn',
        'location',
        'publisher',
        'indexing'
      ],
      'book_chapters': [
        'title',
        'year',
        'level',
        'book_title',
        'publisher',
        'isbn',
        'chapter_no'
      ],
      'books_authored': ['title', 'year', 'level', 'publisher', 'isbn'],
      'edited_volume': ['title', 'year', 'level', 'publisher', 'isbn'],
      'patent': [
        'title',
        'year',
        'country',
        'patent_no',
        'application_no',
        'date',
        'link'
      ],
    };
    for (final t in _pubTypes) {
      _formKeys[t.apiKey] = GlobalKey<FormState>();
      _formControllers[t.apiKey] = {
        for (var k in keys[t.apiKey]!) k: TextEditingController()
      };
      _selectedAuthors[t.apiKey] = [];
      _selectedCoAuthors[t.apiKey] = [];
      _selectedInventors[t.apiKey] = [];
    }
  }

  List<dynamic> get _filtered {
    final list =
        (_publicationsData[_pubTypes[_selectedTypeIndex].apiKey] as List?) ??
            [];
    if (_searchQuery.isEmpty) return list;
    return list
        .where((p) => (p['title'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = context.staffThemeWatch;
    final authProvider = context.read<AuthProvider>();
    final isHod = authProvider.userRole == UserRole.hod;

    if (_showAddForm) return _buildAddForm(theme);

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: _buildAppBar(theme),
      drawer: AppDrawer(isHod: isHod, currentRoute: '/publications'),
      body: FadeTransition(
        opacity: _pageEnterFade,
        child: SlideTransition(
          position: _pageEnterSlide,
          child: Column(
            children: [
              _buildTabBar(theme),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadAllData,
                  color: theme.cyan,
                  backgroundColor: theme.surface,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    child: Column(
                      children: [
                        _buildStatsCard(theme),
                        const SizedBox(height: 12),
                        _buildSearchBar(theme),
                        const SizedBox(height: 14),
                        _buildList(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(theme),
    );
  }

  // ── App Bar (matching dashboard style) ────────────────────────────────────

  PreferredSizeWidget _buildAppBar(StaffThemeProvider theme) {
    final type = _pubTypes[_selectedTypeIndex];
    final total = _pubTypes.fold(
        0, (s, t) => s + ((_publicationsData[t.apiKey] as List?)?.length ?? 0));

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _appBarGlow,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.cyan.withOpacity(0.15 + _appBarGlow.value * 0.12),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.cyan.withOpacity(0.05 + _appBarGlow.value * 0.04),
                blurRadius: 20,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  // Container(
                  //   width: 32, height: 32,
                  //   decoration: BoxDecoration(
                  //     gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                  //     borderRadius: BorderRadius.circular(10),
                  //     boxShadow: [BoxShadow(color: theme.cyan.withOpacity(0.35), blurRadius: 8)],
                  //   ),
                  //   child: Icon(type.icon, color: Colors.white, size: 16),
                  // ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publications',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3),
                        ),
                        Text(
                          type.name,
                          style: TextStyle(
                              color: theme.cyan.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.cyan.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.cyan,
                          boxShadow: [
                            BoxShadow(
                                color: theme.cyan.withOpacity(0.6),
                                blurRadius: 4)
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('$total',
                          style: TextStyle(
                              color: theme.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border),
                      ),
                      child: Icon(Icons.search_rounded,
                          color: theme.textHigh, size: 18),
                    ),
                    onPressed: () => _showPaperSearchModal(theme),
                  ),
                  _isLoading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: theme.cyan)),
                        )
                      : IconButton(
                          icon: Icon(Icons.refresh_rounded,
                              color: theme.textMid, size: 20),
                          onPressed: _loadAllData,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(StaffThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: _pubTypes.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final selected = i == _selectedTypeIndex;
            final count = (_publicationsData[t.apiKey] as List?)?.length ?? 0;

            return GestureDetector(
              onTap: () {
                if (i == _selectedTypeIndex) return;
                setState(() => _selectedTypeIndex = i);
                _animateTabSwitch();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(colors: [theme.cyan, theme.violet])
                      : null,
                  color: selected ? null : theme.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? Colors.transparent : theme.border),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: theme.cyan.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon,
                      size: 14, color: selected ? Colors.white : theme.textMid),
                  const SizedBox(width: 6),
                  Text(t.name.split(' ')[0],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : theme.textMid)),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.22)
                            : theme.cyan.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : theme.cyan)),
                    ),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Stats Card ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard(StaffThemeProvider theme) {
    final type = _pubTypes[_selectedTypeIndex];
    final current = (_publicationsData[type.apiKey] as List?)?.length ?? 0;
    final total = _pubTypes.fold(
        0, (s, t) => s + ((_publicationsData[t.apiKey] as List?)?.length ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.cyan.withOpacity(theme.isDarkMode ? 0.16 : 0.09),
            theme.violet.withOpacity(theme.isDarkMode ? 0.08 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.cyan.withOpacity(0.22)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: theme.cyan.withOpacity(0.35), blurRadius: 10)
            ],
          ),
          child: Icon(type.icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type.name,
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text('$current in this category',
              style: TextStyle(color: theme.textMid, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$total',
              style: TextStyle(
                  color: theme.cyan,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: theme.cyan.withOpacity(0.35), blurRadius: 8)
                  ])),
          Text('Total', style: TextStyle(color: theme.textLow, fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(StaffThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: theme.textHigh, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by title…',
          hintStyle: TextStyle(color: theme.textLow, fontSize: 13),
          prefixIcon:
              Icon(Icons.search_rounded, color: theme.textMid, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon:
                      Icon(Icons.clear_rounded, color: theme.textMid, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''))
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList(StaffThemeProvider theme) {
    if (_isLoading) return _buildShimmer(theme);
    final pubs = _filtered;
    if (pubs.isEmpty) return _buildEmpty(theme);

    return SlideTransition(
      position: _tabSlide,
      child: FadeTransition(
        opacity: _tabFade,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pubs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i >= _cardControllers.length)
              return _buildPubCard(theme, pubs[i]);
            return FadeTransition(
              opacity: _cardFades[i],
              child: SlideTransition(
                position: _cardSlides[i],
                child: _buildPubCard(theme, pubs[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPubCard(StaffThemeProvider theme, dynamic pub) {
    final type = _pubTypes[_selectedTypeIndex];
    final title = pub['title'] ?? 'Untitled';
    final year = pub['year']?.toString() ?? '';
    final journal = pub['journal_name'] ??
        pub['conference_name'] ??
        pub['book_title'] ??
        '';
    final doi = pub['doi'] ?? '';
    final if_ = pub['impact_factor']?.toString();
    final cites = pub['citation_count']?.toString();
    final authors =
        (pub['authors'] as List?)?.map((a) => a.toString()).toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cyan.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
              color: theme.cyan.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(theme, pub),
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.cyan.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      theme.cyan.withOpacity(0.14),
                      theme.violet.withOpacity(0.07)
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.cyan.withOpacity(0.18)),
                  ),
                  child: Icon(type.icon, color: theme.cyan, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(type.name,
                          style: TextStyle(
                              color: theme.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 4),
                      Text(title,
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ])),
                if (year.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: theme.elevated2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.border)),
                    child: Text(year,
                        style: TextStyle(
                            color: theme.textMid,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              if (journal.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.newspaper_rounded, size: 12, color: theme.textMid),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(journal,
                          style: TextStyle(color: theme.textMid, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ],
              if (authors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  ...authors.take(3).map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: theme.elevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.border)),
                        child: Text(a,
                            style:
                                TextStyle(color: theme.textMid, fontSize: 10)),
                      )),
                  if (authors.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.cyan.withOpacity(0.18)),
                      ),
                      child: Text('+${authors.length - 3}',
                          style: TextStyle(
                              color: theme.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
              ],
              if (if_ != null || cites != null || doi.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (if_ != null)
                    _chip(theme, 'IF $if_', Icons.trending_up_rounded,
                        theme.green),
                  if (cites != null)
                    _chip(theme, '$cites Citations', Icons.format_quote_rounded,
                        theme.cyan),
                  if (doi.isNotEmpty)
                    _chip(theme, 'DOI', Icons.link_rounded, theme.violet),
                ]),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  _actionBtn(theme, Icons.visibility_outlined, theme.cyan,
                      () => _showDetails(theme, pub)),
                  const SizedBox(width: 8),
                  _actionBtn(theme, Icons.delete_outline_rounded, theme.pink,
                      () => _deletePublication(pub['_id'] ?? '')),
                ]),
                if ((pub['link'] ?? '').toString().isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(colors: [theme.cyan, theme.violet]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: theme.cyan.withOpacity(0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.open_in_new_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text('View',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(
      StaffThemeProvider theme, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _actionBtn(StaffThemeProvider theme, IconData icon, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab(StaffThemeProvider theme) {
    final type = _pubTypes[_selectedTypeIndex];
    return ScaleTransition(
      scale: _fabScale,
      child: GestureDetector(
        onTap: () => setState(() => _showAddForm = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: theme.cyan.withOpacity(0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Add ${type.name.split(' ')[0]}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  // ── Shimmer (fast, smooth) ─────────────────────────────────────────────────

  Widget _buildShimmer(StaffThemeProvider theme) {
    return Column(
      children: List.generate(
          4,
          (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Shimmer.fromColors(
                  baseColor: theme.elevated,
                  highlightColor: theme.elevated2,
                  period: const Duration(milliseconds: 1000),
                  child: Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                      color: theme.elevated2,
                                      borderRadius: BorderRadius.circular(10))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Container(
                                        height: 10,
                                        width: 80,
                                        decoration: BoxDecoration(
                                            color: theme.elevated2,
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                    const SizedBox(height: 6),
                                    Container(
                                        height: 13,
                                        decoration: BoxDecoration(
                                            color: theme.elevated2,
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                  ])),
                              const SizedBox(width: 8),
                              Container(
                                  width: 36,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      color: theme.elevated2,
                                      borderRadius: BorderRadius.circular(8))),
                            ]),
                            const SizedBox(height: 12),
                            Container(
                                height: 11,
                                width: 200,
                                decoration: BoxDecoration(
                                    color: theme.elevated2,
                                    borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 10),
                            Row(children: [
                              Container(
                                  height: 22,
                                  width: 60,
                                  decoration: BoxDecoration(
                                      color: theme.elevated2,
                                      borderRadius: BorderRadius.circular(6))),
                              const SizedBox(width: 6),
                              Container(
                                  height: 22,
                                  width: 60,
                                  decoration: BoxDecoration(
                                      color: theme.elevated2,
                                      borderRadius: BorderRadius.circular(6))),
                            ]),
                          ]),
                    ),
                  ),
                ),
              )),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmpty(StaffThemeProvider theme) {
    final type = _pubTypes[_selectedTypeIndex];
    return FadeTransition(
      opacity: _tabFade,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.cyan.withOpacity(0.1),
                  theme.violet.withOpacity(0.05)
                ]),
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, size: 44, color: theme.cyan),
            ),
            const SizedBox(height: 16),
            Text(
                _searchQuery.isNotEmpty
                    ? 'No results found'
                    : 'No ${type.name} yet',
                style: TextStyle(
                    color: theme.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                _searchQuery.isNotEmpty
                    ? 'Try a different search'
                    : 'Add your first ${type.name.toLowerCase()}',
                style: TextStyle(color: theme.textMid, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() => _showAddForm = true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: theme.cyan.withOpacity(0.28), blurRadius: 10)
                  ],
                ),
                child: Text('Add ${type.name.split(' ')[0]}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Details Sheet ──────────────────────────────────────────────────────────

  void _showDetails(StaffThemeProvider theme, Map<String, dynamic> pub) {
    final type = _pubTypes[_selectedTypeIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.border),
        ),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(type.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Publication Details',
                  style: TextStyle(
                      color: theme.textHigh,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          Divider(color: theme.border, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: pub.entries
                    .where((e) => e.key != '_id' && e.value != null)
                    .map((e) => _detailRow(
                        theme,
                        e.key.replaceAll('_', ' ').toTitleCase(),
                        e.value.toString()))
                    .toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(StaffThemeProvider theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: theme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        Expanded(
            child: Text(value,
                style: TextStyle(color: theme.textHigh, fontSize: 13))),
      ]),
    );
  }

  // ── Paper Search Modal ─────────────────────────────────────────────────────

  void _showPaperSearchModal(StaffThemeProvider theme) {
    _paperSearchController.clear();
    setState(() {
      _searchResults = [];
      _selectedPaper = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: theme.border),
          ),
          child: Column(children: [
            Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: theme.cyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.travel_explore_rounded,
                        color: theme.cyan, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Search Papers',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text('Import from Crossref',
                          style: TextStyle(color: theme.textMid, fontSize: 11)),
                    ])),
                IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textMid),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Divider(color: theme.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(
                    color: theme.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border)),
                child: TextField(
                  controller: _paperSearchController,
                  style: TextStyle(color: theme.textHigh, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Title, author, DOI…',
                    hintStyle: TextStyle(color: theme.textLow),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: theme.cyan, size: 20),
                    suffixIcon: _isSearchingPapers
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: theme.cyan)))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 500), () async {
                      await _searchPapers(v);
                      setModal(() {});
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off_rounded,
                          size: 44, color: theme.textLow),
                      const SizedBox(height: 10),
                      Text('Search for papers above',
                          style: TextStyle(color: theme.textMid, fontSize: 13)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = _searchResults[i];
                        final sel = _selectedPaper == p;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedPaper = p);
                            setModal(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: sel
                                  ? theme.cyan.withOpacity(0.06)
                                  : theme.elevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel ? theme.cyan : theme.border,
                                  width: sel ? 1.5 : 1),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['title'],
                                      style: TextStyle(
                                          color: theme.textHigh,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  if ((p['journal'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(p['journal'],
                                        style: TextStyle(
                                            color: theme.textMid, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                  if ((p['year'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(p['year'],
                                        style: TextStyle(
                                            color: theme.cyan,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ]),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.border),
                      foregroundColor: theme.textMid,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: _selectedPaper != null
                          ? LinearGradient(colors: [theme.cyan, theme.violet])
                          : null,
                      color: _selectedPaper == null ? theme.elevated : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: _selectedPaper == null
                          ? null
                          : () {
                              _fillFromPaper();
                              Navigator.pop(ctx);
                            },
                      child: Text('Import Paper',
                          style: TextStyle(
                            color: _selectedPaper != null
                                ? Colors.white
                                : theme.textLow,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          )),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADD FORM
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAddForm(StaffThemeProvider theme) {
    final type = _pubTypes[_selectedTypeIndex];
    final c = _formControllers[type.apiKey]!;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(bottom: BorderSide(color: theme.border)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: theme.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border)),
                    child: Icon(Icons.arrow_back_rounded,
                        color: theme.textHigh, size: 18),
                  ),
                  onPressed: () => setState(() {
                    _showAddForm = false;
                    _clearForm();
                  }),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [theme.cyan, theme.violet]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: theme.cyan.withOpacity(0.35), blurRadius: 8)
                    ],
                  ),
                  child: Icon(type.icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Add Publication',
                          style: TextStyle(
                              color: theme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      Text(type.name,
                          style: TextStyle(
                              color: theme.cyan.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ])),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: theme.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border)),
                    child: Icon(Icons.travel_explore_rounded,
                        color: theme.cyan, size: 18),
                  ),
                  onPressed: () => _showPaperSearchModal(theme),
                ),
                const SizedBox(width: 4),
              ]),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKeys[type.apiKey],
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildFormTypeSelector(theme),
            const SizedBox(height: 20),
            if (_selectedPaper != null) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.cyan.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cyan.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: theme.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Imported',
                            style: TextStyle(
                                color: theme.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        Text(_selectedPaper!['title'],
                            style:
                                TextStyle(color: theme.textHigh, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ])),
                  IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: theme.textMid, size: 16),
                      onPressed: () => setState(() => _selectedPaper = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                ]),
              ),
            ],
            _formField(theme, c, 'title', 'Title *', 'Publication title',
                Icons.title_rounded,
                isRequired: true),
            const SizedBox(height: 14),
            _formField(theme, c, 'year', 'Year *', '2024',
                Icons.calendar_today_rounded,
                isRequired: true, keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            if (type.apiKey != 'patent') ...[
              _dropdownField(theme, c, 'level', 'Level *', Icons.flag_rounded,
                  _levelOptions),
              const SizedBox(height: 14),
            ],
            ..._typeFields(theme, type, c),
            const SizedBox(height: 14),
            if (type.apiKey == 'patent')
              _staffSelector(
                  theme,
                  type,
                  'Inventors *',
                  _selectedInventors,
                  (ids) =>
                      setState(() => _selectedInventors[type.apiKey] = ids))
            else ...[
              _staffSelector(theme, type, 'Authors *', _selectedAuthors,
                  (ids) => setState(() => _selectedAuthors[type.apiKey] = ids)),
              const SizedBox(height: 14),
              _staffSelector(
                  theme,
                  type,
                  'Co-Authors (Optional)',
                  _selectedCoAuthors,
                  (ids) =>
                      setState(() => _selectedCoAuthors[type.apiKey] = ids),
                  required: false),
            ],
            const SizedBox(height: 14),
            _formField(theme, c, 'link', 'Link (optional)', 'https://doi.org/…',
                Icons.link_rounded),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.cyan, theme.violet]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: theme.cyan.withOpacity(0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: TextButton(
                  onPressed: _isSubmitting ? null : _addPublication,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Add ${type.name}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _typeFields(StaffThemeProvider theme, _PubType type,
      Map<String, TextEditingController> c) {
    switch (type.apiKey) {
      case 'journal_articles':
        return [
          _formField(theme, c, 'journal_name', 'Journal Name *', 'e.g. Nature',
              Icons.newspaper_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _formField(theme, c, 'volume', 'Volume', 'e.g. 12',
                    Icons.format_list_numbered_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _formField(theme, c, 'issue', 'Issue', 'e.g. 3',
                    Icons.format_list_numbered_rtl_rounded)),
          ]),
          const SizedBox(height: 14),
          _formField(
              theme, c, 'issn', 'ISSN', '1234-5678', Icons.numbers_rounded),
          const SizedBox(height: 14),
          _formField(
              theme, c, 'pages', 'Pages', '45-52', Icons.pageview_rounded),
          const SizedBox(height: 14),
          _formField(
              theme, c, 'doi', 'DOI', '10.1000/xyz123', Icons.link_rounded),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _formField(theme, c, 'impact_factor', 'Impact Factor',
                    '5.6', Icons.trending_up_rounded,
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
                child: _formField(theme, c, 'citation_count', 'Citations', '42',
                    Icons.format_quote_rounded,
                    keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 14),
          _dropdownField(theme, c, 'indexing', 'Indexing', Icons.list_rounded,
              _indexingOptions),
        ];
      case 'conference_papers':
        return [
          _formField(theme, c, 'conference_name', 'Conference Name *',
              'e.g. IEEE Conf.', Icons.groups_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'location', 'Location', 'New York, USA',
              Icons.location_on_rounded),
          const SizedBox(height: 14),
          _formField(theme, c, 'publisher', 'Publisher *', 'Publisher name',
              Icons.business_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'isbn', 'ISBN', '978-3-16-148410-0',
              Icons.numbers_rounded),
          const SizedBox(height: 14),
          _dropdownField(theme, c, 'indexing', 'Indexing', Icons.list_rounded,
              _indexingOptions),
        ];
      case 'book_chapters':
        return [
          _formField(theme, c, 'book_title', 'Book Title *', 'Book title',
              Icons.book_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'publisher', 'Publisher *', 'Publisher name',
              Icons.business_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'chapter_no', 'Chapter No.', 'e.g. 3',
              Icons.format_list_numbered_rounded),
          const SizedBox(height: 14),
          _formField(theme, c, 'isbn', 'ISBN', '978-3-16-148410-0',
              Icons.numbers_rounded),
        ];
      case 'books_authored':
      case 'edited_volume':
        return [
          _formField(theme, c, 'publisher', 'Publisher *', 'Publisher name',
              Icons.business_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'isbn', 'ISBN', '978-3-16-148410-0',
              Icons.numbers_rounded),
        ];
      case 'patent':
        return [
          _formField(theme, c, 'country', 'Country *', 'United States',
              Icons.flag_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'patent_no', 'Patent Number *', 'US1234567B1',
              Icons.numbers_rounded,
              isRequired: true),
          const SizedBox(height: 14),
          _formField(theme, c, 'application_no', 'Application Number *',
              '15/123,456', Icons.description_rounded,
              isRequired: true),
        ];
      default:
        return [];
    }
  }

  Widget _formField(
      StaffThemeProvider theme,
      Map<String, TextEditingController> c,
      String key,
      String label,
      String hint,
      IconData icon,
      {bool isRequired = false,
      TextInputType keyboardType = TextInputType.text}) {
    final ctrl = c[key];
    if (ctrl == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: theme.textHigh,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
            color: theme.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border)),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(color: theme.textHigh, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.textLow, fontSize: 13),
            prefixIcon: Icon(icon, color: theme.cyan, size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
          validator: isRequired
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null,
        ),
      ),
    ]);
  }

  Widget _dropdownField(
      StaffThemeProvider theme,
      Map<String, TextEditingController> c,
      String key,
      String label,
      IconData icon,
      List<String> options) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: theme.textHigh,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
            color: theme.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border)),
        child: DropdownButtonFormField<String>(
          value: c[key]?.text.isEmpty ?? true ? null : c[key]!.text,
          dropdownColor: theme.surface,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: theme.cyan, size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          ),
          hint: Text('Select…',
              style: TextStyle(color: theme.textLow, fontSize: 13)),
          items: options
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o,
                      style: TextStyle(color: theme.textHigh, fontSize: 13))))
              .toList(),
          onChanged: (v) {
            if (v != null && c[key] != null) c[key]!.text = v;
          },
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      ),
    ]);
  }

  Widget _buildFormTypeSelector(StaffThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Icon(Icons.swap_horiz_rounded, size: 16, color: theme.cyan),
            const SizedBox(width: 8),
            Text('Publication Type',
                style: TextStyle(
                    color: theme.textHigh,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: Row(
            children: _pubTypes.asMap().entries.map((e) {
              final i = e.key;
              final t = e.value;
              final sel = i == _selectedTypeIndex;
              return GestureDetector(
                onTap: () {
                  if (i == _selectedTypeIndex) return;
                  final hasData =
                      _formControllers[_pubTypes[_selectedTypeIndex].apiKey]
                              ?.values
                              .any((c) => c.text.isNotEmpty) ??
                          false;
                  if (hasData) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: theme.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Text('Switch type?',
                            style: TextStyle(color: theme.textHigh)),
                        content: Text('This will clear the current form.',
                            style: TextStyle(color: theme.textMid)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel',
                                  style: TextStyle(color: theme.textMid))),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _clearForm();
                                setState(() => _selectedTypeIndex = i);
                              },
                              child: Text('Switch',
                                  style: TextStyle(color: theme.cyan))),
                        ],
                      ),
                    );
                  } else {
                    _clearForm();
                    setState(() => _selectedTypeIndex = i);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? LinearGradient(colors: [theme.cyan, theme.violet])
                        : null,
                    color: sel ? null : theme.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? Colors.transparent : theme.border),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: theme.cyan.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.icon,
                        size: 14, color: sel ? Colors.white : theme.textMid),
                    const SizedBox(width: 6),
                    Text(t.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : theme.textMid)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _staffSelector(StaffThemeProvider theme, _PubType type, String label,
      Map<String, List<String>> map, void Function(List<String>) onChanged,
      {bool required = true}) {
    final selected = map[type.apiKey] ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: theme.textHigh,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => _showStaffModal(theme, type, selected, onChanged),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              color: theme.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border)),
          child: Row(children: [
            Icon(Icons.people_rounded, color: theme.cyan, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: selected.isEmpty
                  ? Text('Tap to select…',
                      style: TextStyle(color: theme.textLow, fontSize: 13))
                  : Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: selected.map((id) {
                        final staff = _allStaff
                            .cast<Map<String, dynamic>>()
                            .firstWhere((s) => s['staff_id'] == id,
                                orElse: () => <String, dynamic>{'name': id});
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: theme.cyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(staff['name'] ?? id,
                              style: TextStyle(
                                  color: theme.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        );
                      }).toList()),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: theme.textMid),
          ]),
        ),
      ),
    ]);
  }

  void _showStaffModal(StaffThemeProvider theme, _PubType type,
      List<String> selected, void Function(List<String>) onChanged) {
    List<String> temp = List.from(selected);
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final List<Map<String, dynamic>> filtered = _allStaff.where((s) {
            if (search.isEmpty) return true;
            final q = search.toLowerCase();
            return (s['name'] ?? '').toLowerCase().contains(q) ||
                (s['staff_id'] ?? '').toLowerCase().contains(q) ||
                (s['department_name'] ?? '').toLowerCase().contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: theme.border),
            ),
            child: Column(children: [
              Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                child: Row(children: [
                  Text('Select Staff',
                      style: TextStyle(
                          color: theme.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: theme.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${temp.length} selected',
                        style: TextStyle(
                            color: theme.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.textMid),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  decoration: BoxDecoration(
                      color: theme.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border)),
                  child: TextField(
                    style: TextStyle(color: theme.textHigh, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID…',
                      hintStyle: TextStyle(color: theme.textLow),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: theme.textMid, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onChanged: (v) => setModal(() => search = v),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final s = filtered[i] as Map<String, dynamic>;
                    final id = s['staff_id'] ?? '';
                    final sel = temp.contains(id);
                    return GestureDetector(
                      onTap: () => setModal(() {
                        if (sel)
                          temp.remove(id);
                        else if (temp.length < 5) temp.add(id);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sel
                              ? theme.cyan.withOpacity(0.07)
                              : theme.elevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel
                                  ? theme.cyan.withOpacity(0.4)
                                  : theme.border,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: sel ? theme.cyan : theme.elevated2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_rounded,
                                color: sel ? Colors.white : theme.textMid,
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(s['name'] ?? '',
                                    style: TextStyle(
                                        color: theme.textHigh,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '${s['staff_id']} • ${s['department_name']}',
                                    style: TextStyle(
                                        color: theme.textMid, fontSize: 11)),
                              ])),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sel ? theme.cyan : Colors.transparent,
                              border: Border.all(
                                  color: sel ? theme.cyan : theme.border),
                            ),
                            child: sel
                                ? const Icon(Icons.check_rounded,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.border),
                        foregroundColor: theme.textMid,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [theme.cyan, theme.violet]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          onChanged(temp);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Confirm',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── Models & Helpers ──────────────────────────────────────────────────────────

class _PubType {
  final String name, apiKey;
  final IconData icon;

  const _PubType(this.name, this.apiKey, this.icon);
}

class _ConfirmDialog extends StatelessWidget {
  final StaffThemeProvider theme;
  final String typeName;
  const _ConfirmDialog({required this.theme, required this.typeName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: theme.pink.withOpacity(0.1), shape: BoxShape.circle),
            child:
                Icon(Icons.delete_outline_rounded, color: theme.pink, size: 28),
          ),
          const SizedBox(height: 16),
          Text('Delete Publication',
              style: TextStyle(
                  color: theme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Remove this ${typeName.toLowerCase()}?',
              style: TextStyle(color: theme.textMid, fontSize: 13)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
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
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

extension _TC on String {
  String toTitleCase() => split(' ')
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
