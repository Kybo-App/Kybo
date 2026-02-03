import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Sistema di Design Kybo Client - Pill-shaped UI
/// Tutti i componenti hanno forme ellittiche/pill
/// Supporta Dark Mode tramite ThemeProvider
/// Colori IDENTICI alla webapp admin

// =============================================================================
// COSTANTI DI DESIGN - COLORI IDENTICI ALLA WEBAPP
// =============================================================================

class KyboColors {
  // Ottiene lo stato dark mode dal ThemeProvider
  static bool isDarkFromContext(BuildContext context) {
    return context.watch<ThemeProvider>().isDarkMode;
  }

  static bool isDarkFromContextRead(BuildContext context) {
    return context.read<ThemeProvider>().isDarkMode;
  }

  // Primary - IDENTICO ADMIN
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF60AD5E);
  static const Color primaryDark = Color(0xFF005005);

  // Backgrounds - Light - IDENTICO ADMIN
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;

  // Backgrounds - Dark - IDENTICO ADMIN
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceElevatedDark = Color(0xFF334155);

  // Text - Light - IDENTICO ADMIN
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Text - Dark - IDENTICO ADMIN
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Accents (same for both modes) - IDENTICO ADMIN
  static const Color accent = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // Role Colors (same for both modes) - IDENTICO ADMIN
  static const Color roleAdmin = Color(0xFF8B5CF6);
  static const Color roleNutritionist = Color(0xFF3B82F6);
  static const Color roleIndependent = Color(0xFFF59E0B);
  static const Color roleUser = Color(0xFF10B981);

  // =========================================================================
  // GETTERS DINAMICI CON CONTEXT
  // =========================================================================

  static Color background(BuildContext context) =>
      isDarkFromContext(context) ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      isDarkFromContext(context) ? surfaceDark : surfaceLight;

  static Color surfaceElevated(BuildContext context) =>
      isDarkFromContext(context) ? surfaceElevatedDark : surfaceLight;

  static Color textPrimary(BuildContext context) =>
      isDarkFromContext(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDarkFromContext(context) ? textSecondaryDark : textSecondaryLight;

  static Color textMuted(BuildContext context) =>
      isDarkFromContext(context) ? textMutedDark : textMutedLight;

  static Color border(BuildContext context) => isDarkFromContext(context)
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  // Shadows - IDENTICO ADMIN
  static List<BoxShadow> softShadow(BuildContext context) => [
        BoxShadow(
          color: isDarkFromContext(context)
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> mediumShadow(BuildContext context) => [
        BoxShadow(
          color: isDarkFromContext(context)
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 10),
          spreadRadius: 2,
        ),
      ];

  // =========================================================================
  // GETTERS SENZA CONTEXT (usa context.read per evitare rebuild)
  // =========================================================================

  static Color backgroundStatic(BuildContext context) =>
      isDarkFromContextRead(context) ? backgroundDark : backgroundLight;

  static Color surfaceStatic(BuildContext context) =>
      isDarkFromContextRead(context) ? surfaceDark : surfaceLight;

  static Color textPrimaryStatic(BuildContext context) =>
      isDarkFromContextRead(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondaryStatic(BuildContext context) =>
      isDarkFromContextRead(context) ? textSecondaryDark : textSecondaryLight;

  static Color textMutedStatic(BuildContext context) =>
      isDarkFromContextRead(context) ? textMutedDark : textMutedLight;
}

// =============================================================================
// SPACING E BORDER RADIUS - IDENTICO ADMIN
// =============================================================================

class KyboSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class KyboBorderRadius {
  static BorderRadius get pill => BorderRadius.circular(100);
  static BorderRadius get large => BorderRadius.circular(24);
  static BorderRadius get medium => BorderRadius.circular(16);
  static BorderRadius get small => BorderRadius.circular(12);
}

// =============================================================================
// PILL BUTTON - Bottone principale ellittico
// =============================================================================

class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isSelected;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double height;
  final double? minWidth;
  final bool expanded;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isSelected = false,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.height = 52,
    this.minWidth,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isSelected ? KyboColors.primary : KyboColors.surface(context));
    final fgColor = textColor ??
        (isSelected ? Colors.white : KyboColors.textPrimary(context));

    Widget button = Container(
      height: height,
      constraints: BoxConstraints(minWidth: minWidth ?? 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: KyboBorderRadius.pill,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: icon != null ? 20 : 28,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: KyboBorderRadius.pill,
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 2)
                  : (!isSelected
                      ? Border.all(color: KyboColors.border(context), width: 1)
                      : null),
              boxShadow: isSelected
                  ? KyboColors.mediumShadow(context)
                  : KyboColors.softShadow(context),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fgColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else if (icon != null) ...[
                  Icon(icon, color: fgColor, size: 22),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

// =============================================================================
// PILL ICON BUTTON - Bottone icona circolare (mobile-friendly)
// =============================================================================

class PillIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final String? tooltip;
  final double size;

  const PillIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? KyboColors.textSecondary(context);
    final bgColor = backgroundColor ?? iconColor.withValues(alpha: 0.1);

    final button = Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

// =============================================================================
// PILL CARD - Card con bordi arrotondati
// =============================================================================

class PillCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool elevated;

  const PillCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        boxShadow: elevated ? KyboColors.softShadow(context) : null,
        border: Border.all(color: KyboColors.border(context), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: KyboBorderRadius.large,
        child: InkWell(
          onTap: onTap,
          borderRadius: KyboBorderRadius.large,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL BADGE - Badge per ruoli e stati
// =============================================================================

class PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool small;

  const PillBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.small = false,
  });

  factory PillBadge.status(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'completato':
      case 'done':
        color = KyboColors.success;
        icon = Icons.check_circle;
        break;
      case 'pending':
      case 'in_attesa':
        color = KyboColors.warning;
        icon = Icons.schedule;
        break;
      case 'error':
      case 'errore':
        color = KyboColors.error;
        icon = Icons.error;
        break;
      default:
        color = KyboColors.accent;
        icon = Icons.info;
    }

    return PillBadge(
      label: status.toUpperCase(),
      color: color,
      icon: icon,
      small: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 10 : 14,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 12 : 14, color: color),
            SizedBox(width: small ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: small ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PILL SEARCH - Barra di ricerca ellittica
// =============================================================================

class PillSearch extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final double? width;

  const PillSearch({
    super.key,
    this.controller,
    this.hintText = "Cerca...",
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 52,
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.pill,
        border: Border.all(color: KyboColors.border(context), width: 1),
        boxShadow: KyboColors.softShadow(context),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: KyboColors.textPrimary(context)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle:
              TextStyle(color: KyboColors.textMuted(context), fontSize: 15),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: KyboColors.textMuted(context),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL TEXT FIELD - Campo di input con stile pill
// =============================================================================

class PillTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final bool showPasswordToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const PillTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.showPasswordToggle = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<PillTextField> createState() => _PillTextFieldState();
}

class _PillTextFieldState extends State<PillTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: TextStyle(
              color: KyboColors.textSecondary(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: KyboColors.surface(context),
            borderRadius:
                widget.maxLines > 1 ? KyboBorderRadius.large : KyboBorderRadius.pill,
            border: Border.all(color: KyboColors.border(context), width: 1),
            boxShadow: KyboColors.softShadow(context),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText:
                widget.showPasswordToggle ? _obscureText : widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            style: TextStyle(
              color: KyboColors.textPrimary(context),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: KyboColors.textMuted(context),
                fontSize: 15,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: KyboColors.textMuted(context),
                      size: 22,
                    )
                  : null,
              suffixIcon: widget.showPasswordToggle
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: KyboColors.textMuted(context),
                        size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    )
                  : widget.suffix,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: widget.maxLines > 1 ? 16 : 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PILL LIST TILE - List tile con stile pill
// =============================================================================

class PillListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const PillListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? KyboColors.surface(context),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: KyboColors.border(context), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: KyboBorderRadius.medium,
        child: InkWell(
          onTap: onTap,
          borderRadius: KyboBorderRadius.medium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: KyboColors.textPrimary(context),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: KyboColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL CHIP - Chip selezionabile
// =============================================================================

class PillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? selectedColor;

  const PillChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? KyboColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : KyboColors.surface(context),
          borderRadius: KyboBorderRadius.pill,
          border: Border.all(
            color: isSelected ? color : KyboColors.border(context),
            width: 1,
          ),
          boxShadow: isSelected ? KyboColors.softShadow(context) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : KyboColors.textSecondary(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL TAB BAR - Tab bar con stile pill
// =============================================================================

class PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color? selectedColor;

  const PillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KyboColors.background(context),
        borderRadius: KyboBorderRadius.pill,
        border: Border.all(color: KyboColors.border(context), width: 1),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (selectedColor ?? KyboColors.primary)
                      : Colors.transparent,
                  borderRadius: KyboBorderRadius.pill,
                  boxShadow: isSelected ? KyboColors.softShadow(context) : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : KyboColors.textSecondary(context),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// PILL BOTTOM NAV - Bottom navigation con stile pill
// =============================================================================

class PillBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const PillBottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class PillBottomNav extends StatelessWidget {
  final List<PillBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PillBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = currentIndex == index;

            return GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 20 : 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? KyboColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: KyboBorderRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                      color: isSelected
                          ? KyboColors.primary
                          : KyboColors.textMuted(context),
                      size: 24,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: KyboColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL DIALOG - Dialog con stile pill
// =============================================================================

Future<T?> showPillDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: KyboColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: KyboColors.textSecondary(context),
                  fontSize: 15,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 16),
              content,
            ],
            if (actions != null && actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .map((action) => Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: action,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// =============================================================================
// PILL SNACKBAR - Snackbar con stile pill
// =============================================================================

void showPillSnackbar({
  required BuildContext context,
  required String message,
  IconData? icon,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor ?? KyboColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.pill),
      margin: const EdgeInsets.all(16),
      duration: duration,
    ),
  );
}

// =============================================================================
// LOADING OVERLAY
// =============================================================================

class PillLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const PillLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: PillCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: KyboColors.primary,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: TextStyle(
                          color: KyboColors.textSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class PillEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const PillEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KyboColors.textMuted(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: KyboColors.textMuted(context),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: KyboColors.textSecondary(context),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class PillSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  const PillSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: KyboColors.textSecondary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
