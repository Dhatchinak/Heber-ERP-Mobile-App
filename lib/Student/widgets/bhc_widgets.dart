// Shared design system for all BHC Student ERP screens
// One accent color (cyan/indigo), consistent spacing, consistent appbar/cards

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

// ── Shared futuristic AppBar ──────────────────────────────────────────────────
class BhcAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData badgeIcon;
  final AnimationController glowCtrl;
  final List<Widget>? actions;
  final bool hasDrawer;

  const BhcAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeIcon,
    required this.glowCtrl,
    this.actions,
    this.hasDrawer = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            bottom: BorderSide(
              color: c.cyan.withOpacity(0.15 + glowCtrl.value * 0.12),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: c.cyan.withOpacity(0.04 + glowCtrl.value * 0.03),
              blurRadius: 20,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              if (hasDrawer)
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
                )
              else
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: c.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: c.textHigh, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: c.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          color: c.cyan.withOpacity(0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        )),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.cyan.withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.cyan,
                      boxShadow: [BoxShadow(color: c.cyan.withOpacity(0.6), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(badge,
                      style: TextStyle(
                        color: c.cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class BhcCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Color? accentColor;

  const BhcCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.padding = const EdgeInsets.all(14),
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    final color = accentColor ?? c.cyan;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c.textHigh,
                  letterSpacing: 0.3,
                )),
          ]),
        ),
        Divider(height: 1, color: c.border),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
class BhcInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const BhcInfoRow({super.key, required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  color: c.textHigh,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ]),
      ),
      if (!isLast) Divider(height: 1, color: c.border),
    ]);
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class BhcStatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const BhcStatChip({super.key, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
              color: c.textMid,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class BhcEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  const BhcEmptyState({super.key, required this.message, required this.icon, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.elevated,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(icon, size: 32, color: c.textLow),
          ),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 13, height: 1.5)),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: c.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.cyan.withOpacity(0.3)),
                ),
                child: Text('Retry',
                    style: TextStyle(
                      color: c.cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────
class BhcLoading extends StatelessWidget {
  final String message;
  const BhcLoading({super.key, this.message = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<ThemeProvider>(context);
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: c.cyan,
            backgroundColor: c.cyan.withOpacity(0.1),
          ),
        ),
        const SizedBox(height: 16),
        Text(message,
            style: TextStyle(color: c.textMid, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Badge pill ────────────────────────────────────────────────────────────────
class BhcBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  const BhcBadge({super.key, required this.text, required this.color, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          )),
    );
  }
}
