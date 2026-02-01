import 'package:flutter/material.dart';

/// Sistema di Design Kybo Admin - Pill-shaped UI
/// Tutti i componenti hanno forme ellittiche/pill

// =============================================================================
// COSTANTI DI DESIGN
// =============================================================================

class KyboColors {
  // Primary
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF60AD5E);
  static const Color primaryDark = Color(0xFF005005);

  // Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Accents
  static const Color accent = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // Role Colors
  static const Color roleAdmin = Color(0xFF8B5CF6);
  static const Color roleNutritionist = Color(0xFF3B82F6);
  static const Color roleIndependent = Color(0xFFF59E0B);
  static const Color roleUser = Color(0xFF10B981);

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];
}

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

class PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isSelected;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double? minWidth;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isSelected = false,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.height = 48,
    this.minWidth,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ??
        (widget.isSelected ? KyboColors.primary : KyboColors.surface);
    final fgColor = widget.textColor ??
        (widget.isSelected ? Colors.white : KyboColors.textPrimary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: widget.height,
        constraints: BoxConstraints(
          minWidth: widget.minWidth ?? 120,
        ),
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        transformAlignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: KyboBorderRadius.pill,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: widget.icon != null ? 20 : 28,
                vertical: 0,
              ),
              decoration: BoxDecoration(
                color: _isHovered && !widget.isSelected
                    ? bgColor.withOpacity(0.95)
                    : bgColor,
                borderRadius: KyboBorderRadius.pill,
                boxShadow: widget.isSelected || _isHovered
                    ? KyboColors.mediumShadow
                    : KyboColors.softShadow,
                border: !widget.isSelected ? Border.all(
                  color: KyboColors.textMuted.withOpacity(0.2),
                  width: 1,
                ) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(fgColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (widget.icon != null) ...[
                    Icon(widget.icon, color: fgColor, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 14,
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

// =============================================================================
// PILL NAV ITEM - Per navigazione orizzontale
// =============================================================================

class PillNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const PillNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<PillNavItem> createState() => _PillNavItemState();
}

class _PillNavItemState extends State<PillNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? KyboColors.primary
                : (_isHovered ? KyboColors.background : Colors.transparent),
            borderRadius: KyboBorderRadius.pill,
            boxShadow: widget.isSelected ? KyboColors.softShadow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected
                    ? Colors.white
                    : (_isHovered ? KyboColors.primary : KyboColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white
                      : (_isHovered ? KyboColors.primary : KyboColors.textSecondary),
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
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

  factory PillBadge.role(String role) {
    Color color;
    IconData icon;

    switch (role.toLowerCase()) {
      case 'admin':
        color = KyboColors.roleAdmin;
        icon = Icons.admin_panel_settings;
        break;
      case 'nutritionist':
        color = KyboColors.roleNutritionist;
        icon = Icons.health_and_safety;
        break;
      case 'independent':
        color = KyboColors.roleIndependent;
        icon = Icons.person;
        break;
      default:
        color = KyboColors.roleUser;
        icon = Icons.person_outline;
    }

    return PillBadge(
      label: role.toUpperCase(),
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
        color: color.withOpacity(0.12),
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
      height: 48,
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
        border: Border.all(
          color: KyboColors.textMuted.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: KyboColors.textMuted,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: KyboColors.textMuted,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL CARD - Card con bordi arrotondati
// =============================================================================

class PillCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const PillCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  @override
  State<PillCard> createState() => _PillCardState();
}

class _PillCardState extends State<PillCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered && widget.onTap != null ? 1.01 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? KyboColors.surface,
          borderRadius: KyboBorderRadius.large,
          boxShadow: _isHovered && widget.onTap != null
              ? KyboColors.mediumShadow
              : KyboColors.softShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: KyboBorderRadius.large,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: KyboBorderRadius.large,
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(20),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PILL ICON BUTTON - Bottone icona circolare
// =============================================================================

class PillIconButton extends StatefulWidget {
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
    this.size = 40,
  });

  @override
  State<PillIconButton> createState() => _PillIconButtonState();
}

class _PillIconButtonState extends State<PillIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.backgroundColor ?? KyboColors.background)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            widget.icon,
            color: widget.color ?? KyboColors.textSecondary,
            size: widget.size * 0.5,
          ),
          onPressed: widget.onPressed,
          padding: EdgeInsets.zero,
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }
    return button;
  }
}

// =============================================================================
// PILL DROPDOWN - Dropdown con stile pill
// =============================================================================

class PillDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
        border: Border.all(
          color: KyboColors.textMuted.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: hint != null ? Text(hint!) : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(
            color: KyboColors.textPrimary,
            fontSize: 14,
          ),
          dropdownColor: KyboColors.surface,
          borderRadius: KyboBorderRadius.medium,
        ),
      ),
    );
  }
}

// =============================================================================
// STAT CARD - Card per statistiche
// =============================================================================

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return PillCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: KyboColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
