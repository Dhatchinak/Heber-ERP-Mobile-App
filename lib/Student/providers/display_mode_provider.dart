import 'package:flutter/material.dart';
import 'package:bhc_erp/Student/services/avatar_service.dart';

/// Single source of truth for avatar vs real-photo display mode.
/// All widgets read from this — no local _showAvatar copies.
class DisplayModeProvider extends ChangeNotifier {
  AvatarConfig? _avatarConfig;
  String? _photoUrl;
  bool _showAvatar = true;

  AvatarConfig? get avatarConfig => _avatarConfig;
  String? get photoUrl => _photoUrl;
  bool get showAvatar => _showAvatar;
  bool get canSwap => _avatarConfig != null && _photoUrl != null;
  bool get hasAvatar => _avatarConfig != null;
  bool get hasPhoto => _photoUrl != null;

  /// Set avatar. Automatically switches to avatar mode.
  void updateAvatar(AvatarConfig? avatar) {
    _avatarConfig = avatar;
    // if (avatar != null) _showAvatar = true;
    notifyListeners();
  }

  /// Set photo URL. Does NOT change mode — just makes swap possible.
  void updatePhotoUrl(String? url) {
    if (_photoUrl == url) return; // no-op if same
    _photoUrl = url;
    notifyListeners();
  }

  void toggle() {
    if (_avatarConfig != null && _photoUrl != null) {
      _showAvatar = !_showAvatar;
      notifyListeners();
    } else if (_photoUrl != null && _avatarConfig == null) {
      // no avatar — force photo mode
      if (_showAvatar) { _showAvatar = false; notifyListeners(); }
    } else if (_avatarConfig != null && _photoUrl == null) {
      if (!_showAvatar) { _showAvatar = true; notifyListeners(); }
    }
  }

  void setShowAvatar(bool value) {
    if (_showAvatar != value) {
      _showAvatar = value;
      notifyListeners();
    }
  }
}