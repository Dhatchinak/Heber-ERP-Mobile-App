import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Avatar configuration – now photo-first.
/// [photoPath]  : local absolute path to the picked/cropped photo (nullable if none yet).
/// [filterIndex]: cartoon-style filter index (0 = no filter, 1-6 = various cartoon looks).
/// [bgColor]    : hex background shown behind the avatar circle.
/// [frameStyle] : 0-5 decorative frame around the avatar.
/// [sticker]    : optional sticker overlay index (0 = none).
/// [badgeColor] : accent color on the frame ring.
class AvatarConfig {
  final String? photoPath;
  final int filterIndex;
  final String bgColor;
  final int frameStyle;
  final int sticker;
  final String badgeColor;

  // Update the default frameStyle to -1 (None)
  const AvatarConfig({
    this.photoPath,
    this.filterIndex = 0,
    this.bgColor = '#EEF2FF',
    this.frameStyle = -1, // ← Changed from 0 to -1 (None by default)
    this.sticker = 0,
    this.badgeColor = '#6366f1',
  });

  AvatarConfig copyWith({
    String? photoPath,
    int? filterIndex,
    String? bgColor,
    int? frameStyle,
    int? sticker,
    String? badgeColor,
    bool clearPhoto = false,
  }) =>
      AvatarConfig(
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        filterIndex: filterIndex ?? this.filterIndex,
        bgColor: bgColor ?? this.bgColor,
        frameStyle: frameStyle ?? this.frameStyle,
        sticker: sticker ?? this.sticker,
        badgeColor: badgeColor ?? this.badgeColor,
      );

  bool get hasPhoto => photoPath != null && File(photoPath!).existsSync();

  Map<String, dynamic> toJson() => {
        'photoPath': photoPath,
        'filterIndex': filterIndex,
        'bgColor': bgColor,
        'frameStyle': frameStyle,
        'sticker': sticker,
        'badgeColor': badgeColor,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> j) => AvatarConfig(
        photoPath: j['photoPath'] as String?,
        filterIndex: j['filterIndex'] ?? 0,
        bgColor: j['bgColor'] ?? '#EEF2FF',
        frameStyle: j['frameStyle'] ?? 0,
        sticker: j['sticker'] ?? 0,
        badgeColor: j['badgeColor'] ?? '#6366f1',
      );
}

// ─── Filter metadata ────────────────────────────────────────────────────────
class FilterInfo {
  final String name;
  final String emoji;
  final String description;
  const FilterInfo(this.name, this.emoji, this.description);
}

const List<FilterInfo> avatarFilters = [
  FilterInfo('Original', '📸', 'Your authentic photo'),
  FilterInfo('Cartoon Pop', '🎭', 'Cell-shaded, vibrant comic style'),
  FilterInfo('Pencil Sketch', '✏️', 'Hand-drawn pencil art effect'),
  FilterInfo('Anime Cel', '🌸', 'Bright anime-style coloring'),
  FilterInfo('Watercolor', '🎨', 'Soft, dreamy artistic wash'),
  FilterInfo('Comic Book', '📚', 'Halftone-inspired pop art'),
  FilterInfo('Oil Painting', '🖼️', 'Rich textured classic look'),
  FilterInfo('Charcoal', '⚫', 'Dark dramatic sketch'),
  FilterInfo('Pastel Dream', '💫', 'Soft romantic tones'),
  FilterInfo('Neon Glow', '🌈', 'Cyberpunk electric style'),
];

// ─── Frame metadata ─────────────────────────────────────────────────────────
// Update the frameLabels list to include "None" as first option:
const List<String> frameLabels = [
  'None', // Index 0 (frameStyle = -1)
  'Classic', // Index 1 (frameStyle = 0)
  'Glow', // Index 2 (frameStyle = 1)
  'Dashed', // Index 3 (frameStyle = 2)
  'Star', // Index 4 (frameStyle = 3)
  'Double', // Index 5 (frameStyle = 4)
  'Gradient' // Index 6 (frameStyle = 5)
];

// ─── Sticker metadata ───────────────────────────────────────────────────────
const List<String> stickerEmojis = [
  '—',
  '⭐',
  '🔥',
  '💯',
  '🎓',
  '👑',
  '✨',
  '🚀',
  '💪',
  '🌟'
];

// ─── Persistence ────────────────────────────────────────────────────────────
class AvatarService {
  static const String _key = 'student_avatar_v2';

  static Future<void> save(String rollNo, AvatarConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_key}_$rollNo', jsonEncode(config.toJson()));
  }

  static Future<AvatarConfig?> load(String rollNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_key}_$rollNo');
      if (raw == null) return null;
      return AvatarConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasAvatar(String rollNo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('${_key}_$rollNo');
  }

  static Future<void> clear(String rollNo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_key}_$rollNo');
  }

  static int hexToColorInt(String hex) {
    final h = hex.replaceAll('#', '');
    return int.parse('FF$h', radix: 16);
  }
}
