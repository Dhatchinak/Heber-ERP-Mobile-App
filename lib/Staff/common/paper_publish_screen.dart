import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';

class PaperPublishScreen extends StatefulWidget {
  const PaperPublishScreen({super.key});

  @override
  State<PaperPublishScreen> createState() => _PaperPublishScreenState();
}

class _PaperPublishScreenState extends State<PaperPublishScreen>
    with TickerProviderStateMixin {
  // ==================== COLORS ====================
  static const _deepBlue = Color(0xFF1E3A8A);
  static const _royalBlue = Color(0xFF2563EB);
  static const _electricBlue = Color(0xFF3B82F6);
  static const _successGreen = Color(0xFF10B981);
  static const _dangerRed = Color(0xFFEF4444);
  static const _bgLight = Color(0xFFF8FAFC);
  static const _cardWhite = Colors.white;
  static const _textDark = Color(0xFF1F2937);
  static const _textMed = Color(0xFF6B7280);
  static const _textLight = Color(0xFF9CA3AF);
  static const _border = Color(0xFFE5E7EB);
  static const List<Color> _gradient = [_deepBlue, _royalBlue, _electricBlue];

  // ==================== PUBLICATION TYPES ====================
  final List<_PubType> _types = [
    _PubType('Journal Articles', 'journal_articles', Icons.article_outlined,
        Color(0xFF2563EB), [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)]),
    _PubType('Conference Papers', 'conference_papers', Icons.groups_outlined,
        Color(0xFF10B981), [Color(0xFF059669), Color(0xFF10B981)]),
    _PubType('Book Chapters', 'book_chapters', Icons.menu_book_outlined,
        Color(0xFF8B5CF6), [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
    _PubType('Books Authored', 'books_authored', Icons.book_outlined,
        Color(0xFFF59E0B), [Color(0xFFD97706), Color(0xFFF59E0B)]),
    _PubType('Edited Volumes', 'edited_volume', Icons.collections_bookmark_outlined,
        Color(0xFFEC4899), [Color(0xFFDB2777), Color(0xFFEC4899)]),
    _PubType('Patents', 'patent', Icons.badge_outlined,
        Color(0xFFEF4444), [Color(0xFFDC2626), Color(0xFFEF4444)]),
  ];

  final List<String> _levelOptions = ['International', 'National', 'Regional', 'Institutional', 'State'];
  final List<String> _indexingOptions = ['Scopus', 'Web of Science', 'UGC Care', 'Google Scholar', 'Others'];

  // ==================== STATE ====================
  int _currentStep = 0;
  int _selectedTypeIdx = 0;
  bool _isSubmitting = false;
  bool _isSearching = false;
  bool _submitted = false;
  String _searchError = '';
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedPaper;
  Timer? _debounce;

  final _searchCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  List<String> _authors = [];
  List<String> _coAuthors = [];
  List<String> _inventors = [];
  List<Map<String, dynamic>> _allStaff = [];

  late AnimationController _stepAnim;
  late AnimationController _successAnim;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _successAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pageCtrl = PageController();
    _initFields();
    _loadStaff();
    _stepAnim.forward();
  }

  @override
  void dispose() {
    _stepAnim.dispose();
    _successAnim.dispose();
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    for (var c in _fields.values) { c.dispose(); }
    super.dispose();
  }

  void _initFields() {
    _fields.clear();
    final key = _types[_selectedTypeIdx].apiKey;
    _fields['title'] = TextEditingController();
    _fields['year'] = TextEditingController();
    if (key != 'patent') _fields['level'] = TextEditingController();
    switch (key) {
      case 'journal_articles':
        for (var f in ['journal_name','issn','volume','issue','pages','doi','impact_factor','citation_count','author_position','link','indexing']) {
          _fields[f] = TextEditingController();
        }
        break;
      case 'conference_papers':
        for (var f in ['conference_name','isbn','location','publisher','indexing']) {
          _fields[f] = TextEditingController();
        }
        break;
      case 'book_chapters':
        for (var f in ['book_title','publisher','isbn','chapter_no']) {
          _fields[f] = TextEditingController();
        }
        break;
      case 'books_authored':
      case 'edited_volume':
        for (var f in ['publisher','isbn']) {
          _fields[f] = TextEditingController();
        }
        break;
      case 'patent':
        for (var f in ['country','patent_no','application_no','date']) {
          _fields[f] = TextEditingController();
        }
        break;
    }
    if (!_fields.containsKey('link')) _fields['link'] = TextEditingController();
    _authors = [];
    _coAuthors = [];
    _inventors = [];
  }

  Future<void> _loadStaff() async {
    try {
      final resp = await http.get(
        Uri.parse('http://117.232.64.75/api/staff/'),
        headers: {'Referer': 'http://117.232.64.75', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is List) {
          setState(() {
            _allStaff = data.where((e) => e is Map<String, dynamic>).map((e) => {
              'staff_id': e['staff_id']?.toString().trim() ?? '',
              'name': e['name']?.toString().trim() ?? 'Unknown',
              'department_name': e['department_name']?.toString().trim() ?? '',
              'designation': e['designation']?.toString().trim() ?? '',
            }).where((e) => e['name']!.isNotEmpty && e['staff_id']!.isNotEmpty).toList().cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _searchPapers(String q) async {
    if (q.length < 3) {
      setState(() { _searchResults = []; _searchError = ''; });
      return;
    }
    setState(() { _isSearching = true; _searchError = ''; });
    try {
      final resp = await http.get(
        Uri.parse('https://api.crossref.org/works?query=$q&rows=20'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final items = json.decode(resp.body)['message']['items'] as List;
        setState(() {
          _searchResults = items.map((i) => <String, dynamic>{
            'title': i['title']?.isNotEmpty == true ? i['title'][0] : 'Unknown',
            'authors': (i['author'] as List?)?.map((a) => '${a['given'] ?? ''} ${a['family'] ?? ''}'.trim()).toList() ?? [],
            'year': i['published-print']?['date-parts']?[0]?[0]?.toString() ?? i['published-online']?['date-parts']?[0]?[0]?.toString() ?? '',
            'journal': i['container-title']?.isNotEmpty == true ? i['container-title'][0] : '',
            'doi': i['DOI'] ?? '',
            'publisher': i['publisher'] ?? '',
            'volume': i['volume']?.toString() ?? '',
            'issue': i['issue']?.toString() ?? '',
            'pages': i['page']?.toString() ?? '',
          }).toList();
          _isSearching = false;
        });
      } else {
        setState(() { _searchError = 'Search failed'; _isSearching = false; });
      }
    } catch (e) {
      setState(() { _searchError = e.toString(); _isSearching = false; });
    }
  }

  void _fillFromPaper() {
    if (_selectedPaper == null) return;
    _fields['title']?.text = _selectedPaper!['title'] ?? '';
    _fields['year']?.text = _selectedPaper!['year'] ?? '';
    final key = _types[_selectedTypeIdx].apiKey;
    switch (key) {
      case 'journal_articles':
        _fields['journal_name']?.text = _selectedPaper!['journal'] ?? '';
        _fields['doi']?.text = _selectedPaper!['doi'] ?? '';
        _fields['volume']?.text = _selectedPaper!['volume'] ?? '';
        _fields['issue']?.text = _selectedPaper!['issue'] ?? '';
        _fields['pages']?.text = _selectedPaper!['pages'] ?? '';
        break;
      case 'conference_papers':
        _fields['conference_name']?.text = _selectedPaper!['journal'] ?? '';
        _fields['publisher']?.text = _selectedPaper!['publisher'] ?? '';
        break;
      case 'book_chapters':
        _fields['book_title']?.text = _selectedPaper!['journal'] ?? '';
        _fields['publisher']?.text = _selectedPaper!['publisher'] ?? '';
        break;
      case 'books_authored':
      case 'edited_volume':
        _fields['publisher']?.text = _selectedPaper!['publisher'] ?? '';
        break;
    }
  }



  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final staffId = auth.userData?['staff_id'];
      if (staffId == null) throw Exception('Staff ID not found');
      final type = _types[_selectedTypeIdx];
      final data = <String, dynamic>{};
      _fields.forEach((k, c) { if (c.text.isNotEmpty) data[k] = c.text; });
      if (type.apiKey == 'patent') {
        data['inventors'] = _inventors;
      } else {
        data['authors'] = _authors;
        data['co_authors'] = _coAuthors;
      }
      final resp = await http.post(
        Uri.parse('http://117.232.64.75/api/staff/publications/$staffId/${type.apiKey}'),
        headers: {'Referer': 'http://117.232.64.75', 'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final r = json.decode(resp.body);
        if (r['success'] == true) {
          setState(() { _submitted = true; _isSubmitting = false; });
          _successAnim.forward();
          return;
        }
      }
      throw Exception('Failed');
    } catch (e) {
      setState(() => _isSubmitting = false);
      _snack('Failed: $e', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err ? _dangerRed : _successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _goStep(int step) {
    _stepAnim.reset();
    setState(() => _currentStep = step);
    _pageCtrl.animateToPage(step, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    _stepAnim.forward();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      _initFields();
      _goStep(1);
    } else if (_currentStep == 1) {
      _fillFromPaper();
      _goStep(2);
    } else if (_currentStep == 2) {
      if (_formKey.currentState?.validate() ?? false) {
        _goStep(3);
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) _goStep(_currentStep - 1);
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccess();
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep0(),
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: _gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (_currentStep > 0) { _prevStep(); } else { Navigator.pop(context); }
        },
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Publish Paper', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Add to your research portfolio', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Step ${_currentStep + 1}/4', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    final icons = [Icons.category, Icons.search, Icons.edit_note, Icons.check_circle];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardWhite,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: List.generate(4, (i) {
          final done = i < _currentStep;
          final active = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0) Expanded(child: Container(height: 2, color: done ? _royalBlue : _border)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: active ? 36 : 28,
                  height: active ? 36 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (done || active) ? const LinearGradient(colors: _gradient) : null,
                    color: (done || active) ? null : _bgLight,
                    border: Border.all(color: (done || active) ? Colors.transparent : _border, width: 1.5),
                    boxShadow: active ? [BoxShadow(color: _royalBlue.withOpacity(0.3), blurRadius: 8)] : null,
                  ),
                  child: Icon(
                    done ? Icons.check : icons[i],
                    size: active ? 18 : 14,
                    color: (done || active) ? Colors.white : _textLight,
                  ),
                ),
                if (i < 3 && i == _currentStep - 1 || (i > 0 && i < 3))
                  const SizedBox()
                else if (i < 3)
                  const SizedBox(),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar() {
    final type = _types[_selectedTypeIdx];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textMed,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _currentStep == 3
                  ? ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.publish, size: 20),
                      label: Text(_isSubmitting ? 'Publishing...' : 'Publish Paper'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      label: const Text('Continue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 0: SELECT TYPE ====================
  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _royalBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _royalBlue.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _royalBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline, color: _royalBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Publication Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                      SizedBox(height: 2),
                      Text('Select the category that best fits your research', style: TextStyle(fontSize: 12, color: _textMed)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_types.length, (i) {
            final t = _types[i];
            final sel = i == _selectedTypeIdx;
            return GestureDetector(
              onTap: () => setState(() => _selectedTypeIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel ? t.color.withOpacity(0.06) : _cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? t.color : _border, width: sel ? 2 : 1),
                  boxShadow: sel
                      ? [BoxShadow(color: t.color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: t.gradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(t.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sel ? t.color : _textDark)),
                          const SizedBox(height: 2),
                          Text(_typeDesc(t.apiKey), style: const TextStyle(fontSize: 11, color: _textMed)),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? t.color : Colors.transparent,
                        border: Border.all(color: sel ? t.color : _border, width: 2),
                      ),
                      child: sel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _typeDesc(String key) {
    switch (key) {
      case 'journal_articles': return 'Peer-reviewed journal publications';
      case 'conference_papers': return 'Papers presented at conferences';
      case 'book_chapters': return 'Chapters published in edited books';
      case 'books_authored': return 'Complete books you have authored';
      case 'edited_volume': return 'Volumes you have edited';
      case 'patent': return 'Patents filed or granted';
      default: return '';
    }
  }

  // ==================== STEP 1: SEARCH PAPER ====================
  Widget _buildStep1() {
    final type = _types[_selectedTypeIdx];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPaper != null) ...[
            _buildSelectedPaperCard(type),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() { _selectedPaper = null; _searchResults = []; _searchCtrl.clear(); }),
                icon: const Icon(Icons.swap_horiz, size: 20),
                label: const Text('Change Paper'),
                style: TextButton.styleFrom(
                  foregroundColor: type.color,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: type.color.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _successGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _successGreen.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: _successGreen, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Paper selected! Tap Continue to fill in details, or Change Paper to pick a different one.', style: TextStyle(fontSize: 12, color: _textMed))),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: type.gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Search Research Papers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Search by title, DOI or author name', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
                color: _cardWhite,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search papers...',
                  hintStyle: const TextStyle(color: _textLight, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: type.color),
                  suffixIcon: _isSearching
                      ? Container(width: 20, height: 20, margin: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: type.color))
                      : _searchCtrl.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() { _searchResults = []; }); })
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () => _searchPapers(v));
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _nextStep,
                child: Text('Skip — Enter details manually', style: TextStyle(fontSize: 13, color: type.color, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 8),
            if (_searchError.isNotEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_searchError, style: const TextStyle(color: _dangerRed, fontSize: 13)),
              )),
            ..._searchResults.map((p) => _buildPaperResultCard(p, type)),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPaperCard(_PubType type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: type.color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: type.color, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Selected Paper', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: type.color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_selectedPaper!['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark), maxLines: 3, overflow: TextOverflow.ellipsis),
          if ((_selectedPaper!['authors'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Authors: ${(_selectedPaper!['authors'] as List).take(3).join(', ')}', style: const TextStyle(fontSize: 12, color: _textMed)),
          ],
          if ((_selectedPaper!['journal'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_selectedPaper!['journal'], style: TextStyle(fontSize: 12, color: type.color, fontStyle: FontStyle.italic)),
          ],
          if ((_selectedPaper!['year'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(6)),
              child: Text('Year: ${_selectedPaper!['year']}', style: const TextStyle(fontSize: 11, color: _textMed, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperResultCard(Map<String, dynamic> p, _PubType type) {
    final sel = _selectedPaper == p;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaper = p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? type.color.withOpacity(0.05) : _cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? type.color : _border, width: sel ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['title'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? type.color : _textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
            if ((p['authors'] as List).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text((p['authors'] as List).take(3).join(', '), style: const TextStyle(fontSize: 11, color: _textMed), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if ((p['journal'] ?? '').isNotEmpty) Expanded(child: Text(p['journal'], style: const TextStyle(fontSize: 11, color: _textMed), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if ((p['year'] ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(4)),
                    child: Text(p['year'], style: const TextStyle(fontSize: 10, color: _textMed)),
                  ),
              ],
            ),
            if ((p['doi'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('DOI: ${p['doi']}', style: TextStyle(fontSize: 10, color: type.color, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== STEP 2: FILL DETAILS ====================
  Widget _buildStep2() {
    final type = _types[_selectedTypeIdx];
    final key = type.apiKey;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: LinearGradient(colors: type.gradient), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(type.icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${type.name} Details', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Text('Fill in all required fields *', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            _field('title', 'Title *', 'Enter publication title', Icons.title, req: true),
            _field('year', 'Year *', 'e.g., 2024', Icons.calendar_today, req: true, num: true),
            if (key != 'patent') _dropdown('level', 'Level *', _levelOptions, Icons.flag, type.color),
            if (key == 'journal_articles') ...[
              _field('journal_name', 'Journal Name *', 'e.g., Nature', Icons.newspaper, req: true),
              Row(children: [Expanded(child: _field('volume', 'Volume', 'e.g., 12', Icons.format_list_numbered)), const SizedBox(width: 10), Expanded(child: _field('issue', 'Issue', 'e.g., 3', Icons.format_list_numbered_rtl))]),
              _field('issn', 'ISSN', 'e.g., 1234-5678', Icons.numbers),
              _field('pages', 'Pages', 'e.g., 45-52', Icons.pageview),
              _field('doi', 'DOI', 'e.g., 10.1000/xyz123', Icons.link),
              Row(children: [Expanded(child: _field('impact_factor', 'Impact Factor', 'e.g., 5.6', Icons.trending_up, num: true)), const SizedBox(width: 10), Expanded(child: _field('citation_count', 'Citations', 'e.g., 42', Icons.format_quote, num: true))]),
              _dropdown('indexing', 'Indexing', _indexingOptions, Icons.list, type.color),
            ],
            if (key == 'conference_papers') ...[
              _field('conference_name', 'Conference Name *', 'e.g., IEEE', Icons.meeting_room, req: true),
              _field('location', 'Location', 'e.g., New York', Icons.location_on),
              _field('isbn', 'ISBN', 'e.g., 978-3-16-148410-0', Icons.numbers),
              _field('publisher', 'Publisher', 'Publisher name', Icons.business),
            ],
            if (key == 'book_chapters') ...[
              _field('book_title', 'Book Title *', 'Enter book title', Icons.book, req: true),
              _field('publisher', 'Publisher *', 'Publisher name', Icons.business, req: true),
              _field('chapter_no', 'Chapter No', 'e.g., 3', Icons.format_list_numbered),
              _field('isbn', 'ISBN', 'e.g., 978-3-16-148410-0', Icons.numbers),
            ],
            if (key == 'books_authored' || key == 'edited_volume') ...[
              _field('publisher', 'Publisher *', 'Publisher name', Icons.business, req: true),
              _field('isbn', 'ISBN', 'e.g., 978-3-16-148410-0', Icons.numbers),
            ],
            if (key == 'patent') ...[
              _field('country', 'Country *', 'e.g., United States', Icons.flag, req: true),
              _field('patent_no', 'Patent Number *', 'e.g., US1234567B1', Icons.numbers, req: true),
              _field('application_no', 'Application Number *', 'e.g., 15/123,456', Icons.description, req: true),
            ],
            if (key == 'patent') _buildPeopleSelector('Inventors *', _inventors, (v) => setState(() => _inventors = v))
            else ...[
              _buildPeopleSelector('Authors *', _authors, (v) => setState(() => _authors = v)),
              _buildPeopleSelector('Co-Authors', _coAuthors, (v) => setState(() => _coAuthors = v)),
            ],
            _field('link', 'Link (Optional)', 'https://doi.org/...', Icons.link),
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label, String hint, IconData icon, {bool req = false, bool num = false}) {
    final ctrl = _fields[key];
    if (ctrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _border), color: _cardWhite),
            child: TextFormField(
              controller: ctrl,
              keyboardType: num ? TextInputType.number : TextInputType.text,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint, hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                prefixIcon: Icon(icon, color: _types[_selectedTypeIdx].color, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: req ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String key, String label, List<String> opts, IconData icon, Color color) {
    final ctrl = _fields[key];
    if (ctrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _border), color: _cardWhite),
            child: DropdownButtonFormField<String>(
              value: ctrl.text.isEmpty ? null : ctrl.text,
              decoration: InputDecoration(
                hintText: 'Select $label', hintStyle: const TextStyle(color: _textLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(icon, color: color, size: 18),
              ),
              items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) { if (v != null) ctrl.text = v; },
              validator: label.contains('*') ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleSelector(String label, List<String> selected, Function(List<String>) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
            Text('${selected.length}/5', style: const TextStyle(fontSize: 12, color: _textMed)),
          ]),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showStaffSheet(selected, onChanged),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _border), color: _cardWhite),
              child: Row(children: [
                const Icon(Icons.person_add_outlined, color: _textMed, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: selected.isEmpty
                      ? const Text('Tap to select...', style: TextStyle(fontSize: 13, color: _textLight))
                      : Wrap(spacing: 4, runSpacing: 4, children: selected.map((id) {
                          final s = _allStaff.firstWhere((s) => s['staff_id'] == id, orElse: () => {'name': id});
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _royalBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(s['name'] ?? id, style: const TextStyle(fontSize: 11, color: _royalBlue, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () { final l = List<String>.from(selected); l.remove(id); onChanged(l); },
                                child: const Icon(Icons.close, size: 12, color: _textMed),
                              ),
                            ]),
                          );
                        }).toList()),
                ),
                const Icon(Icons.arrow_drop_down, color: _textLight),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showStaffSheet(List<String> selected, Function(List<String>) onChanged) {
    final temp = List<String>.from(selected);
    var filtered = List<Map<String, dynamic>>.from(_allStaff);
    final sc = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: const BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: _gradient),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Select Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Selected: ${temp.length}/5', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ]),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: sc,
                decoration: InputDecoration(
                  hintText: 'Search by name or department...', hintStyle: const TextStyle(color: _textLight),
                  prefixIcon: const Icon(Icons.search, color: _textMed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (v) {
                  ss(() {
                    filtered = v.isEmpty ? List.from(_allStaff) : _allStaff.where((s) {
                      final q = v.toLowerCase();
                      return (s['name'] ?? '').toString().toLowerCase().contains(q) || (s['department_name'] ?? '').toString().toLowerCase().contains(q) || (s['staff_id'] ?? '').toString().toLowerCase().contains(q);
                    }).toList();
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  final id = s['staff_id'].toString();
                  final isSel = temp.contains(id);
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: isSel ? _royalBlue : _bgLight, child: Icon(Icons.person, color: isSel ? Colors.white : _textMed, size: 20)),
                    title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('${s['staff_id']} • ${s['department_name']}', style: const TextStyle(fontSize: 11, color: _textMed)),
                    trailing: Checkbox(value: isSel, activeColor: _royalBlue, onChanged: (v) {
                      ss(() { if (isSel) { temp.remove(id); } else if (temp.length < 5) { temp.add(id); } });
                    }),
                    onTap: () { ss(() { if (isSel) { temp.remove(id); } else if (temp.length < 5) { temp.add(id); } }); },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () { onChanged(temp); Navigator.pop(ctx); },
                  style: ElevatedButton.styleFrom(backgroundColor: _royalBlue, foregroundColor: Colors.white),
                  child: const Text('Confirm'),
                )),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  // ==================== STEP 3: REVIEW ====================
  Widget _buildStep3() {
    final type = _types[_selectedTypeIdx];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: type.gradient), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.rate_review, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Review & Publish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Verify all details before publishing', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          _reviewSection('Publication Type', type.name, type.icon, type.color),
          ..._fields.entries.where((e) => e.value.text.isNotEmpty).map((e) => _reviewItem(
            e.key.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
            e.value.text,
          )),
          if (_authors.isNotEmpty) _reviewItem('Authors', _authors.map((id) {
            final s = _allStaff.firstWhere((s) => s['staff_id'] == id, orElse: () => {'name': id});
            return s['name'] ?? id;
          }).join(', ')),
          if (_coAuthors.isNotEmpty) _reviewItem('Co-Authors', _coAuthors.map((id) {
            final s = _allStaff.firstWhere((s) => s['staff_id'] == id, orElse: () => {'name': id});
            return s['name'] ?? id;
          }).join(', ')),
          if (_inventors.isNotEmpty) _reviewItem('Inventors', _inventors.map((id) {
            final s = _allStaff.firstWhere((s) => s['staff_id'] == id, orElse: () => {'name': id});
            return s['name'] ?? id;
          }).join(', ')),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Please review all details carefully. Once published, you can manage this from your publications list.', style: TextStyle(fontSize: 12, color: _textMed))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _reviewSection(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMed)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ]),
      ]),
    );
  }

  Widget _reviewItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMed))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: _textDark))),
      ]),
    );
  }

  // ==================== SUCCESS ====================
  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Center(
        child: AnimatedBuilder(
          animation: _successAnim,
          builder: (_, __) => Opacity(
            opacity: _successAnim.value,
            child: Transform.scale(
              scale: 0.8 + (_successAnim.value * 0.2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [_successGreen, Color(0xFF34D399)]),
                      boxShadow: [BoxShadow(color: _successGreen.withOpacity(0.3), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 24),
                  const Text('Published Successfully!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textDark)),
                  const SizedBox(height: 8),
                  const Text('Your paper has been added to your portfolio', style: TextStyle(fontSize: 14, color: _textMed)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Publications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PubType {
  final String name, apiKey;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  _PubType(this.name, this.apiKey, this.icon, this.color, this.gradient);
}
