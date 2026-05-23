// ============================================================
// campus_pet_game.dart - COMPLETELY FIXED
// Fixed: All overflow issues + High score saving
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ───────────────────────────────────────────────
const double _kGravity = 1100.0;
const double _kGap = 210.0;
const double _kObstacleW = 52.0;
const double _kObstacleSpeed = 150.0;
const double _kGroundH = 70.0;
const double _kPetSize = 54.0;
const double _kXPos = 90.0;

const int _kBaseXP = 10;
const int _kPipeXP = 5;
const int _kLevelXP = 100;

// ─── Pet Types ────────────────────────────────────────────────
enum PetType { cat, dog, owl }

extension PetTypeExt on PetType {
  String get emoji {
    switch (this) {
      case PetType.cat: return '🐱';
      case PetType.dog: return '🐶';
      case PetType.owl: return '🦉';
    }
  }
  String get name {
    switch (this) {
      case PetType.cat: return 'Cat';
      case PetType.dog: return 'Dog';
      case PetType.owl: return 'Owl';
    }
  }
  String get ability {
    switch (this) {
      case PetType.cat: return 'Lucky – coins +20%';
      case PetType.dog: return 'Second Chance Bounce';
      case PetType.owl: return 'Double Jump';
    }
  }
  String get abilityHint {
    switch (this) {
      case PetType.cat: return 'Collect more coins!';
      case PetType.dog: return 'Survive one collision!';
      case PetType.owl: return 'Tap again mid-air!';
    }
  }
}

// ─── Pet Save Data ────────────────────────────────────────────
class PetData {
  final PetType type;
  final int level;
  final int xp;
  final int coins;
  final int highScore;

  const PetData({
    required this.type,
    required this.level,
    required this.xp,
    required this.coins,
    this.highScore = 0,
  });

  int get xpToNextLevel => _kLevelXP;
  double get xpProgress => (xp % _kLevelXP) / _kLevelXP;

  PetData copyWith({PetType? type, int? level, int? xp, int? coins, int? highScore}) => PetData(
    type: type ?? this.type,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    highScore: highScore ?? this.highScore,
  );

  static Future<PetData?> load(String rollNo) async {
    final p = await SharedPreferences.getInstance();
    final typeIdx = p.getInt('pet_type_$rollNo');
    if (typeIdx == null) return null;
    return PetData(
      type: PetType.values[typeIdx.clamp(0, 2)],
      level: p.getInt('pet_level_$rollNo') ?? 1,
      xp: p.getInt('pet_xp_$rollNo') ?? 0,
      coins: p.getInt('pet_coins_$rollNo') ?? 0,
      highScore: p.getInt('pet_highscore_$rollNo') ?? 0,
    );
  }

  Future<void> save(String rollNo) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('pet_type_$rollNo', type.index);
    await p.setInt('pet_level_$rollNo', level);
    await p.setInt('pet_xp_$rollNo', xp);
    await p.setInt('pet_coins_$rollNo', coins);
    await p.setInt('pet_highscore_$rollNo', highScore);
  }
}

class _Obstacle {
  double x;
  final double gapY;
  bool scored;
  _Obstacle({required this.x, required this.gapY}) : scored = false;
}

enum _GameState { choosePet, idle, playing, dead, levelUp }

class CampusPetGame extends StatefulWidget {
  final String rollNo;
  final String studentName;
  final double attendancePercentage;

  const CampusPetGame({
    super.key,
    required this.rollNo,
    required this.studentName,
    required this.attendancePercentage,
  });

  @override
  State<CampusPetGame> createState() => _CampusPetGameState();
}

class _CampusPetGameState extends State<CampusPetGame>
    with TickerProviderStateMixin {

  static const _bg    = Color(0xFF0A0E1A);
  static const _surf  = Color(0xFF0F1628);
  static const _card  = Color(0xFF151D35);
  static const _cyan  = Color(0xFF00D4FF);
  static const _violet= Color(0xFF7C3AED);
  static const _pink  = Color(0xFFF472B6);
  static const _green = Color(0xFF10F5A8);
  static const _amber = Color(0xFFFFB347);
  static const _border= Color(0xFF1E2D4A);

  PetData? _pet;
  _GameState _state = _GameState.idle;
  double _petY = 0;
  double _petVelocity = 0;
  bool _dogAbilityUsed = false;
  bool _owlSecondJump = false;
  int _score = 0;
  int _sessionCoins = 0;
  final List<_Obstacle> _obstacles = [];
  final Random _rng = Random();

  late Ticker _ticker;
  Duration? _lastTick;

  late AnimationController _flapCtrl;
  late AnimationController _deathCtrl;
  late AnimationController _scoreCtrl;
  late AnimationController _bgPulse;

  double _sw = 0, _sh = 0;

  double get _jumpPower {
    final att = widget.attendancePercentage;
    if (att >= 90) return -560.0;
    if (att >= 75) return -480.0;
    if (att >= 60) return -420.0;
    return -370.0;
  }

  String get _mood {
    final att = widget.attendancePercentage;
    if (att >= 75) return '😄';
    if (att >= 50) return '😐';
    return '😢';
  }

  String get _moodLabel {
    final att = widget.attendancePercentage;
    if (att >= 75) return 'Happy';
    if (att >= 50) return 'Okay';
    return 'Sad';
  }

  String get _jumpLabel {
    final att = widget.attendancePercentage;
    if (att >= 90) return '3× Power ⚡';
    if (att >= 75) return '2× Power ⬆';
    if (att >= 60) return '1.5× Power';
    return '1× Power';
  }

  @override
  void initState() {
    super.initState();
    _flapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120))..repeat(reverse: true);
    _deathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scoreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _bgPulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _ticker = createTicker(_tick);
    _loadPet();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flapCtrl.dispose();
    _deathCtrl.dispose();
    _scoreCtrl.dispose();
    _bgPulse.dispose();
    super.dispose();
  }

  Future<void> _loadPet() async {
    final saved = await PetData.load(widget.rollNo);
    if (mounted) {
      setState(() {
        if (saved == null) {
          _state = _GameState.choosePet;
        } else {
          _pet = saved;
          _state = _GameState.idle;
        }
      });
    }
  }

  Future<void> _selectPet(PetType t) async {
    final pet = PetData(type: t, level: 1, xp: 0, coins: 0);
    await pet.save(widget.rollNo);
    setState(() {
      _pet = pet;
      _state = _GameState.idle;
    });
  }

  void _startGame() {
    _score = 0;
    _sessionCoins = 0;
    _petY = 0;
    _petVelocity = 0;
    _dogAbilityUsed = false;
    _owlSecondJump = false;
    _obstacles.clear();
    _state = _GameState.playing;
    _lastTick = null;
    _ticker.start();
    HapticFeedback.lightImpact();
  }

  void _tick(Duration elapsed) {
    if (_state != _GameState.playing) { _ticker.stop(); return; }

    final dt = _lastTick == null ? 0.016 : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final groundY = _sh / 2 - _kGroundH;

    _petVelocity += _kGravity * dt;
    _petY += _petVelocity * dt;

    if (_petY >= groundY - _kPetSize / 2) {
      _petY = groundY - _kPetSize / 2;
      _die();
      return;
    }
    if (_petY < -_sh / 2 + _kPetSize) {
      _petY = -_sh / 2 + _kPetSize;
      _petVelocity = 0;
    }

    if (_obstacles.isEmpty || _sw - _obstacles.last.x > _sh * 0.72) {
      final gapY = _rng.nextDouble() * (_sh - _kGap - _kGroundH - 80) - (_sh / 2 - 80);
      _obstacles.add(_Obstacle(x: _sw + _kObstacleW, gapY: gapY));
    }

    final toRemove = <_Obstacle>[];
    for (final obs in _obstacles) {
      obs.x -= _kObstacleSpeed * dt;
      if (obs.x < -_kObstacleW - 10) {
        toRemove.add(obs);
        continue;
      }

      if (!obs.scored && obs.x + _kObstacleW < _kXPos) {
        obs.scored = true;
        _score++;
        _sessionCoins += (_pet?.type == PetType.cat) ? 2 : 1;
        _scoreCtrl.forward(from: 0);
        HapticFeedback.selectionClick();
      }

      final petLeft = _kXPos - _kPetSize * 0.4;
      final petRight = _kXPos + _kPetSize * 0.4;
      final petTop = _petY - _kPetSize * 0.4;
      final petBot = _petY + _kPetSize * 0.4;
      final obsLeft = obs.x - _kObstacleW / 2 + 4;
      final obsRight = obs.x + _kObstacleW / 2 - 4;

      if (petRight > obsLeft && petLeft < obsRight) {
        final gapTop = obs.gapY - _kGap / 2;
        final gapBot = obs.gapY + _kGap / 2;
        if (petTop < gapTop || petBot > gapBot) {
          if (_pet?.type == PetType.dog && !_dogAbilityUsed) {
            _dogAbilityUsed = true;
            _petVelocity = _jumpPower * 0.6;
            HapticFeedback.heavyImpact();
            _deathCtrl.forward(from: 0).then((_) => _deathCtrl.reverse());
          } else {
            _die();
            return;
          }
        }
      }
    }
    _obstacles.removeWhere((o) => toRemove.contains(o));
    setState(() {});
  }

  void _die() {
    _ticker.stop();
    _state = _GameState.dead;
    HapticFeedback.heavyImpact();
    _deathCtrl.forward(from: 0);
    _saveProgress();
    setState(() {});
  }

  Future<void> _saveProgress() async {
    if (_pet == null) return;
    final earnedXP = _kBaseXP + _score * _kPipeXP;
    final coins = _pet!.type == PetType.cat ? (_sessionCoins * 1.2).round() : _sessionCoins;

    int newXP = _pet!.xp + earnedXP;
    int newLevel = _pet!.level;
    while (newXP >= _kLevelXP) {
      newXP -= _kLevelXP;
      newLevel++;
    }
    
    final newHighScore = _score > _pet!.highScore ? _score : _pet!.highScore;
    
    _pet = _pet!.copyWith(
      level: newLevel,
      xp: newXP,
      coins: _pet!.coins + coins,
      highScore: newHighScore,
    );
    await _pet!.save(widget.rollNo);
  }

  void _onTap() {
    if (_state == _GameState.idle || _state == _GameState.dead) {
      setState(() => _startGame());
      return;
    }
    if (_state != _GameState.playing) return;

    if (_pet?.type == PetType.owl && _petVelocity > 0 && !_owlSecondJump) {
      _owlSecondJump = true;
      _petVelocity = _jumpPower * 0.85;
      HapticFeedback.mediumImpact();
    } else {
      _owlSecondJump = false;
      _petVelocity = _jumpPower;
      HapticFeedback.lightImpact();
    }
    _flapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(builder: (ctx, constraints) {
        _sw = constraints.maxWidth;
        _sh = constraints.maxHeight;
        return GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(children: [
            _buildBackground(),
            _buildGround(),
            if (_state == _GameState.playing || _state == _GameState.dead) ..._buildObstacles(),
            if (_state != _GameState.choosePet) _buildPet(),
            if (_state == _GameState.playing) _buildHUD(),
            if (_state == _GameState.choosePet) _buildChoosePet(),
            if (_state == _GameState.idle) _buildIdleOverlay(),
            if (_state == _GameState.dead) _buildDeadOverlay(),
          ]),
        );
      }),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgPulse,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 1.2,
            colors: [
              _cyan.withOpacity(0.04 + _bgPulse.value * 0.03),
              _violet.withOpacity(0.06 + _bgPulse.value * 0.02),
              _bg,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGround() {
    return Positioned(
      left: 0, right: 0,
      bottom: 0,
      height: _kGroundH,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_surf, _card],
          ),
          border: const Border(top: BorderSide(color: _cyan, width: 1.5)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(8, (i) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('📚', style: TextStyle(fontSize: 20)),
            )),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildObstacles() {
    return _obstacles.map((obs) {
      final cx = obs.x;
      final gapTop = _sh / 2 + obs.gapY - _kGap / 2;
      final gapBot = _sh / 2 + obs.gapY + _kGap / 2;
      return Stack(children: [
        if (gapTop > 20)
          Positioned(
            left: cx - _kObstacleW / 2,
            top: 0,
            width: _kObstacleW,
            height: gapTop.clamp(0.0, _sh - _kGroundH - 20),
            child: const _BookPillar(isTop: true),
          ),
        if (_sh - gapBot - _kGroundH > 20)
          Positioned(
            left: cx - _kObstacleW / 2,
            top: gapBot.clamp(0.0, _sh - _kGroundH - 20),
            width: _kObstacleW,
            height: (_sh - gapBot - _kGroundH).clamp(0.0, _sh - _kGroundH - 20),
            child: const _BookPillar(isTop: false),
          ),
      ]);
    }).toList();
  }

  Widget _buildPet() {
    final screenY = _sh / 2 + _petY - _kPetSize / 2;
    final isDead = _state == _GameState.dead;
    final isFlapping = _state == _GameState.playing && _petVelocity < 0;

    return Positioned(
      left: _kXPos - _kPetSize / 2,
      top: screenY.clamp(0, _sh - _kPetSize - _kGroundH),
      child: AnimatedBuilder(
        animation: Listenable.merge([_flapCtrl, _deathCtrl]),
        builder: (_, __) {
          final rot = isDead ? _deathCtrl.value * 0.5 : (isFlapping ? -0.2 : 0.1);
          final shake = isDead ? sin(_deathCtrl.value * pi * 6) * 4 : 0.0;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateZ(rot)..translate(shake, 0.0),
            child: Container(
              width: _kPetSize,
              height: _kPetSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _card,
                border: Border.all(color: isDead ? _pink : _cyan, width: 2),
                boxShadow: [BoxShadow(color: (isDead ? _pink : _cyan).withOpacity(0.5), blurRadius: 16, spreadRadius: 2)],
              ),
              child: Center(child: Text(_pet?.type.emoji ?? '🐱', style: const TextStyle(fontSize: 30))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHUD() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _scoreCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: 1.0 + _scoreCtrl.value * 0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _surf.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cyan.withOpacity(0.4)),
                      ),
                      child: Text('⭐ $_score', style: const TextStyle(color: _cyan, fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _surf.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amber.withOpacity(0.4)),
                  ),
                  child: Text('🪙 $_sessionCoins', style: const TextStyle(color: _amber, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                if (_pet?.type == PetType.owl)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _violet.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _violet.withOpacity(0.5)),
                    ),
                    child: Text(_owlSecondJump ? '🦉💨' : '🦉✨', style: const TextStyle(fontSize: 14)),
                  ),
                if (_pet?.type == PetType.dog)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _dogAbilityUsed ? _border : _green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _dogAbilityUsed ? _border : _green.withOpacity(0.5)),
                    ),
                    child: Text(_dogAbilityUsed ? '🐶💔' : '🐶🛡️', style: const TextStyle(fontSize: 14)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _surf.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 5),
                  Text(
                    '$_jumpLabel  |  ${widget.attendancePercentage.toStringAsFixed(0)}% att  |  $_mood $_moodLabel',
                    style: const TextStyle(color: Color(0xFF7B8DB8), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleOverlay() {
    if (_pet == null) return const SizedBox();
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surf,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border, width: 1.5),
              boxShadow: [BoxShadow(color: _cyan.withOpacity(0.08), blurRadius: 40)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _card,
                    border: Border.all(color: _cyan, width: 2.5),
                    boxShadow: [BoxShadow(color: _cyan.withOpacity(0.4), blurRadius: 20)],
                  ),
                  child: Center(child: Text(_pet!.type.emoji, style: const TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 12),
                Text('${_pet!.type.name} $_mood', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Level ${_pet!.level}  •  ${_pet!.coins} coins', style: TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _XpBar(progress: _pet!.xpProgress, level: _pet!.level),
                const SizedBox(height: 10),
                Text('🏆 High Score: ${_pet!.highScore}', style: TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _surf,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    '⚡ $_jumpLabel  •  ${widget.attendancePercentage.toStringAsFixed(0)}% attendance',
                    style: TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_pet!.type.ability, style: TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _bgPulse,
                  builder: (_, __) => Opacity(
                    opacity: 0.6 + _bgPulse.value * 0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_cyan, _violet]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: _cyan.withOpacity(0.35), blurRadius: 16)],
                      ),
                      child: const Text('TAP TO PLAY', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _state = _GameState.choosePet),
                  child: Text('Change Pet', style: TextStyle(color: _violet, fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadOverlay() {
    if (_pet == null) return const SizedBox();
    final earnedXP = _kBaseXP + _score * _kPipeXP;
    final coins = _pet!.type == PetType.cat ? (_sessionCoins * 1.2).round() : _sessionCoins;
    final isNewHighScore = _score > _pet!.highScore;

    return AnimatedBuilder(
      animation: _deathCtrl,
      builder: (_, __) => Opacity(
        opacity: _deathCtrl.value.clamp(0.0, 1.0),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surf,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _border, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💥', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 8),
                    const Text('GAME OVER', style: TextStyle(color: _pink, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    _StatRow('Score', '$_score', _cyan),
                    if (isNewHighScore) ...[
                      const SizedBox(height: 2),
                      _StatRow('NEW HIGH SCORE!', '🏆 $_score 🏆', _amber),
                    ],
                    const SizedBox(height: 4),
                    _StatRow('Best Score', '${_pet!.highScore}', _amber),
                    const SizedBox(height: 4),
                    _StatRow('XP Earned', '+$earnedXP XP', _green),
                    const SizedBox(height: 4),
                    _StatRow('Coins', '+$coins 🪙', _amber),
                    const SizedBox(height: 10),
                    _XpBar(progress: _pet!.xpProgress, level: _pet!.level),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NeonButton(label: 'RETRY', color: _cyan, onTap: _onTap),
                        const SizedBox(width: 12),
                        _NeonButton(label: 'MENU', color: _violet, onTap: () => setState(() => _state = _GameState.idle)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoosePet() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surf,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎓 CAMPUS PET', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text('Choose your study companion', style: TextStyle(color: Color(0xFF7B8DB8), fontSize: 12)),
                const SizedBox(height: 16),
                ...PetType.values.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PetCard(type: t, onSelect: () => _selectPet(t)),
                )),
                const SizedBox(height: 6),
                Text('${widget.attendancePercentage.toStringAsFixed(0)}% attendance → $_jumpLabel',
                    style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting Widgets ──────────────────────────────────────

class _PetCard extends StatelessWidget {
  final PetType type;
  final VoidCallback onSelect;
  const _PetCard({required this.type, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF151D35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E2D4A)),
        ),
        child: Row(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(type.ability, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 10)),
                  Text(type.abilityHint, style: const TextStyle(color: Color(0xFF7B8DB8), fontSize: 9)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Text('SELECT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookPillar extends StatelessWidget {
  final bool isTop;
  const _BookPillar({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0xFF0F1628), Color(0xFF151D35)],
        ),
        border: Border(
          left: const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
          right: const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
          top: isTop ? const BorderSide(color: Color(0xFF00D4FF), width: 1.5) : BorderSide.none,
          bottom: isTop ? BorderSide.none : const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          Text('📚', style: TextStyle(fontSize: 16)),
          Text('📖', style: TextStyle(fontSize: 16)),
          Text('📕', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final double progress;
  final int level;
  const _XpBar({required this.progress, required this.level});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lv.$level', style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.w800)),
            Text('${(progress * 100).toInt()}% to next', style: const TextStyle(color: Color(0xFF7B8DB8), fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E2D4A),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF7B8DB8), fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeonButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.6)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)],
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}