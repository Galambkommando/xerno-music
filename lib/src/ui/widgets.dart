import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../logic/source_resolver.dart';
import '../logic/track_query.dart';
import '../models/library.dart';
import '../models/track.dart';
import '../models/user_library.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    required this.frosted,
    this.color = AppColors.surface,
    this.border,
    this.radius = 0,
    this.shadow = false,
    this.blur = false,
    super.key,
  });

  final Widget child;
  final bool frosted;
  final Color color;
  final BoxBorder? border;
  final double radius;
  final bool shadow;

  /// Backdrop blur is reserved for the sidebar, the player dock, and sheets.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(this.radius);
    if (!frosted) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: border,
        ),
        child: child,
      );
    }
    if (!blur) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF151F1A),
          borderRadius: radius,
          border: border ?? Border.all(color: const Color(0xFF23332B)),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB8101613),
              borderRadius: radius,
              border:
                  border ??
                  Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Stack(
              children: [
                child,
                const Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x38FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryActionPill extends StatelessWidget {
  const PrimaryActionPill({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return _ActionPill(
      label: label,
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.accent, AppColors.accentBright],
      ),
      foreground: AppColors.ivory,
      border: Border.all(color: AppColors.mint.withValues(alpha: 0.85)),
    );
  }
}

class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return _ActionPill(
      label: label,
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      fill: Colors.white.withValues(alpha: 0.06),
      foreground: AppColors.ivory,
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    );
  }
}

class SecondaryActionPill extends GlassActionButton {
  const SecondaryActionPill({
    required super.label,
    required super.onPressed,
    super.icon,
    super.tooltip,
    super.key,
  });
}

class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = 34,
    this.iconSize = 18,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scale = !enabled
        ? 1.0
        : _down
        ? 0.90
        : _hover
        ? 1.12
        : 1.0;
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: Duration(milliseconds: _down ? 90 : 150),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              mouseCursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.active
                      ? AppColors.accent.withValues(alpha: _hover ? 0.75 : 0.55)
                      : Colors.white.withValues(alpha: _hover ? 0.14 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.active || _hover
                        ? AppColors.mint.withValues(alpha: _hover ? 0.65 : 0.4)
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: _hover
                      ? [
                          BoxShadow(
                            color: AppColors.mint.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color: enabled
                          ? AppColors.ivory
                          : AppColors.sage.withValues(alpha: 0.45),
                      shadows: _hover
                          ? [
                              Shadow(
                                color: AppColors.mint.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    if (widget.active)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip, child: button);
  }
}

class PlayerTransportButton extends StatelessWidget {
  const PlayerTransportButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = 44,
    this.iconSize = 26,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      active: active,
      size: size,
      iconSize: iconSize,
    );
  }
}

class AnimatedPlayButton extends StatefulWidget {
  const AnimatedPlayButton({
    required this.playing,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    super.key,
  });

  final bool playing;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  State<AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _down = false;
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(AnimatedPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _syncPulse();
  }

  void _syncPulse() {
    if (!widget.playing) {
      _pulse?.stop();
      return;
    }
    _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_pulse!.isAnimating) _pulse!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scale = !enabled
        ? 1.0
        : _down
        ? 0.92
        : _hover
        ? 1.08
        : 1.0;
    final button = AnimatedBuilder(
      animation: _pulse ?? const AlwaysStoppedAnimation<double>(0),
      builder: (context, _) {
        final pulse = widget.playing ? (_pulse?.value ?? 0) : 0.0;
        return _playFace(enabled, scale, pulse);
      },
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip, child: button);
  }

  Widget _playFace(bool enabled, double scale, double pulse) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              mouseCursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Ink(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.playing
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.accentBright, AppColors.mint],
                        ),
                  color: widget.playing ? AppColors.ivory : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mint.withValues(
                        alpha: 0.35 + (pulse * 0.25) + (_hover ? 0.15 : 0),
                      ),
                      blurRadius: _hover ? 24 : 16,
                      spreadRadius: _hover ? 2 : 0,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: RotationTransition(
                      turns: Tween<double>(
                        begin: 0.08,
                        end: 0,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    widget.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(widget.playing),
                    color: widget.playing
                        ? AppColors.obsidian
                        : AppColors.ivory,
                    size: widget.size * 0.56,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.border,
    this.icon,
    this.tooltip,
    this.gradient,
    this.fill,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;
  final Gradient? gradient;
  final Color? fill;
  final Color foreground;
  final BoxBorder border;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          mouseCursor: onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: fill,
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onPressed == null
                          ? foreground.withValues(alpha: 0.4)
                          : foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

class CoverImage extends StatelessWidget {
  const CoverImage({this.url, this.size, this.radius = 12, super.key});

  final String? url;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = url == null || url!.isEmpty
        ? const _CoverFallback()
        : Image.network(
            url!,
            fit: BoxFit.cover,
            cacheWidth: size == null ? 256 : (size! * 2).round().clamp(64, 512),
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stack) => const _CoverFallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const _CoverFallback();
            },
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.elevated, AppColors.accent],
        ),
      ),
      child: Center(
        child: Icon(Icons.graphic_eq_rounded, color: AppColors.ivory, size: 28),
      ),
    );
  }
}

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    required this.child,
    required this.enabled,
    this.coverUrl,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: ColoredBox(color: AppColors.obsidian)),
        if (enabled) const RepaintBoundary(child: _AuroraField()),
        if (enabled && coverUrl != null && coverUrl!.isNotEmpty)
          RepaintBoundary(
            child: Opacity(
              opacity: 0.42,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 128,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.obsidian.withValues(alpha: enabled ? 0.15 : 0.72),
                  AppColors.obsidian.withValues(alpha: enabled ? 0.28 : 0.84),
                  AppColors.obsidian.withValues(alpha: enabled ? 0.55 : 0.92),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuroraField extends StatelessWidget {
  const _AuroraField();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _GlowOrb(
            alignment: Alignment(-0.85, -0.75),
            color: AppColors.glowDeep,
            radius: 280,
          ),
          _GlowOrb(
            alignment: Alignment(0.9, -0.4),
            color: AppColors.accent,
            radius: 240,
          ),
          _GlowOrb(
            alignment: Alignment(0.15, 0.85),
            color: AppColors.mint,
            radius: 220,
          ),
          _GlowOrb(
            alignment: Alignment(-0.2, 0.1),
            color: AppColors.glowIvory,
            radius: 180,
            alpha: 0.16,
          ),
          _GlowOrb(
            alignment: Alignment(0.55, 0.35),
            color: AppColors.glowSoft,
            radius: 160,
            alpha: 0.14,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.color,
    required this.radius,
    this.alpha = 0.55,
  });

  final Alignment alignment;
  final Color color;
  final double radius;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
  }
}

class SeekBar extends StatefulWidget {
  const SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.buffered = Duration.zero,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  bool _hover = false;
  bool _drag = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds <= 0
        ? 1
        : widget.duration.inMilliseconds;
    final played = (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
    final loaded = (widget.buffered.inMilliseconds / total).clamp(0.0, 1.0);
    final thick = _hover || _drag;
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekAt(double dx) {
          final fraction = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          widget.onSeek(Duration(milliseconds: (fraction * total).round()));
        }

        return MouseRegion(
          cursor: _drag
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seekAt(details.localPosition.dx),
            onHorizontalDragStart: (_) => setState(() => _drag = true),
            onHorizontalDragUpdate: (details) =>
                seekAt(details.localPosition.dx),
            onHorizontalDragEnd: (_) => setState(() => _drag = false),
            onHorizontalDragCancel: () => setState(() => _drag = false),
            child: SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: thick ? 7 : 4,
                    color: AppColors.border,
                  ),
                  FractionallySizedBox(
                    widthFactor: loaded.toDouble(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      height: thick ? 7 : 4,
                      color: AppColors.elevated,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: played.toDouble(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      height: thick ? 7 : 4,
                      color: AppColors.mint,
                    ),
                  ),
                  Align(
                    alignment: Alignment(played * 2 - 1, 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: thick ? 14 : 8,
                      height: thick ? 14 : 8,
                      decoration: BoxDecoration(
                        color: AppColors.ivory,
                        shape: BoxShape.circle,
                        boxShadow: thick
                            ? [
                                BoxShadow(
                                  color: AppColors.mint.withValues(alpha: 0.85),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}

class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected ? AppColors.accentBright : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: selected ? AppColors.ivory : AppColors.sage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    required this.playlist,
    required this.onTap,
    this.onPlay,
    this.frosted = true,
    super.key,
  });

  final PlaylistSummary playlist;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      frosted: frosted,
      radius: 16,
      shadow: true,
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CoverImage(url: playlist.coverUrl, radius: 12),
                    ),
                    if (onPlay != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _CoverPlayButton(onPressed: onPlay!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.2,
                  color: AppColors.ivory,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${playlist.trackCount} tracks',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlayButton extends StatelessWidget {
  const _CoverPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.mint, width: 1.4),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        mouseCursor: SystemMouseCursors.click,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.play_arrow_rounded, color: AppColors.ivory),
        ),
      ),
    );
  }
}

class TrackBrowser extends ConsumerStatefulWidget {
  const TrackBrowser({
    required this.tracks,
    required this.title,
    this.eyebrow = 'LIBRARY',
    this.subtitle,
    this.coverUrl,
    this.positions,
    this.contextLabel,
    this.onPinAll,
    this.customPlaylistId,
    this.trailing,
    this.initialQuery = '',
    super.key,
  });

  final List<TrackRecord> tracks;
  final String title;
  final String eyebrow;
  final String? subtitle;
  final String? coverUrl;
  final Map<String, int>? positions;
  final String? contextLabel;
  final VoidCallback? onPinAll;
  final String? customPlaylistId;
  final Widget? trailing;
  final String initialQuery;

  @override
  ConsumerState<TrackBrowser> createState() => _TrackBrowserState();
}

class _TrackBrowserState extends ConsumerState<TrackBrowser> {
  TrackSort _sort = TrackSort.position;
  bool _ascending = true;
  late String _query;
  late final TextEditingController _filter;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _filter = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(TrackBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery.isNotEmpty &&
        widget.initialQuery != _filter.text) {
      _query = widget.initialQuery;
      _filter.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = sortTracks(
      filterTracks(widget.tracks, _query),
      _sort,
      ascending: _ascending,
      positions: widget.positions,
    );
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final frosted = ref.watch(settingsProvider).frostedGlass;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: GlassSurface(
            frosted: frosted,
            radius: 18,
            shadow: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.coverUrl != null) ...[
                    CoverImage(
                      url: widget.coverUrl,
                      size: wide ? 132 : 84,
                      radius: 14,
                    ),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(widget.eyebrow),
                        const SizedBox(height: 8),
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${filtered.length} tracks',
                              style: AppTheme.tabular.copyWith(fontSize: 13),
                            ),
                            PrimaryActionPill(
                              label: 'Play',
                              icon: Icons.play_arrow_rounded,
                              onPressed: filtered.isEmpty
                                  ? null
                                  : () =>
                                        unawaited(_play(context, filtered, 0)),
                            ),
                            GlassActionButton(
                              label: 'Shuffle',
                              icon: Icons.shuffle_rounded,
                              onPressed: filtered.isEmpty
                                  ? null
                                  : () => unawaited(
                                      _play(
                                        context,
                                        [...filtered]..shuffle(),
                                        0,
                                      ),
                                    ),
                            ),
                            if (widget.onPinAll != null)
                              GlassActionButton(
                                label: 'Pin offline',
                                icon: Icons.download_rounded,
                                onPressed: widget.onPinAll,
                              ),
                            if (widget.trailing != null) widget.trailing!,
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filter,
                  decoration: xernoField(
                    'Filter',
                    hint: 'Title, artist, album, year',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<TrackSort>(
                initialValue: _sort,
                tooltip: 'Sort',
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => [
                  for (final entry in trackSortLabels.entries)
                    PopupMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                child: IgnorePointer(
                  child: GlassActionButton(
                    label: trackSortLabels[_sort] ?? 'Sort',
                    icon: Icons.sort_rounded,
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassActionButton(
                label: _ascending ? 'Asc' : 'Desc',
                icon: _ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                tooltip: _ascending ? 'Ascending' : 'Descending',
                onPressed: () => setState(() => _ascending = !_ascending),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Nothing matches this view yet.'))
              : widget.customPlaylistId == null
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 148),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final track = filtered[index];
                    return TrackRow(
                      track: track,
                      number: widget.positions?[track.id] ?? index + 1,
                      onPlay: () => _play(context, filtered, index),
                    );
                  },
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 148),
                  buildDefaultDragHandles: false,
                  itemCount: filtered.length,
                  onReorderItem: (from, to) {
                    final playlistId = widget.customPlaylistId!;
                    final data = ref.read(userLibraryProvider).valueOrNull;
                    final playlist = data?.playlists
                        .where((item) => item.id == playlistId)
                        .firstOrNull;
                    if (playlist == null) return;
                    final moving = filtered[from];
                    final source = playlist.trackIds.indexOf(moving.id);
                    final destinationId =
                        filtered[to.clamp(0, filtered.length - 1)].id;
                    final destination = playlist.trackIds.indexOf(
                      destinationId,
                    );
                    if (source < 0 || destination < 0) return;
                    unawaited(
                      ref
                          .read(userLibraryProvider.notifier)
                          .mutate(
                            (current) => current.reorderTracks(
                              playlistId,
                              source,
                              destination,
                            ),
                          ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final track = filtered[index];
                    return TrackRow(
                      key: ValueKey('${track.id}-$index'),
                      track: track,
                      number: index + 1,
                      dragIndex: _query.isEmpty && _sort == TrackSort.position
                          ? index
                          : null,
                      customPlaylistId: widget.customPlaylistId,
                      onPlay: () => _play(context, filtered, index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _play(
    BuildContext context,
    List<TrackRecord> tracks,
    int index,
  ) async {
    final note = await playTracks(
      ref,
      tracks: tracks,
      index: index,
      contextLabel: widget.contextLabel ?? widget.title,
    );
    if (!context.mounted) return;
    showNote(context, note);
  }
}

class TrackRow extends ConsumerWidget {
  const TrackRow({
    required this.track,
    required this.number,
    required this.onPlay,
    this.dragIndex,
    this.customPlaylistId,
    super.key,
  });

  final TrackRecord track;
  final int number;
  final VoidCallback onPlay;
  final int? dragIndex;
  final String? customPlaylistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playerProvider).snapshot;
    final favorite =
        ref.watch(userLibraryProvider).valueOrNull?.isFavorite(track.id) ??
        false;
    final active = snapshot.track?.id == track.id;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Material(
      color: active
          ? AppColors.accent.withValues(alpha: 0.38)
          : Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? AppColors.mint.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onPlay,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: const Icon(Icons.drag_indicator, size: 18),
                ),
              SizedBox(
                width: 36,
                child: Text(
                  active ? '▶' : number.toString().padLeft(2, '0'),
                  style: AppTheme.tabular.copyWith(
                    color: active ? AppColors.mint : AppColors.sage,
                    fontSize: 13,
                  ),
                ),
              ),
              CoverImage(url: track.coverUrl, size: 42, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              color: active ? AppColors.mint : AppColors.ivory,
                            ),
                          ),
                        ),
                        if (track.explicit) ...[
                          const SizedBox(width: 6),
                          const _ExplicitMark(),
                        ],
                      ],
                    ),
                    Text(
                      track.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (wide)
                Expanded(
                  flex: 3,
                  child: Text(
                    track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: 52,
                child: Text(
                  track.durationFormatted,
                  textAlign: TextAlign.right,
                  style: AppTheme.tabular.copyWith(fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: favorite ? 'Remove from favorites' : 'Favorite',
                onPressed: () {
                  unawaited(
                    ref
                        .read(userLibraryProvider.notifier)
                        .mutate((current) => current.toggleFavorite(track.id)),
                  );
                },
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? AppColors.mint : AppColors.sage,
                  size: 18,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Track actions',
                popUpAnimationStyle: AnimationStyle.noAnimation,
                onSelected: (value) => _action(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'next', child: Text('Play next')),
                  const PopupMenuItem(
                    value: 'server_link',
                    child: Text('Server link (RöcsögeCloud)'),
                  ),
                  const PopupMenuItem(
                    value: 'queue',
                    child: Text('Add to queue'),
                  ),
                  const PopupMenuItem(
                    value: 'playlist',
                    child: Text('Add to playlist'),
                  ),
                  const PopupMenuItem(value: 'pin', child: Text('Pin offline')),
                  const PopupMenuItem(
                    value: 'artist',
                    child: Text('Go to artist'),
                  ),
                  const PopupMenuItem(
                    value: 'album',
                    child: Text('Go to album'),
                  ),
                  const PopupMenuItem(value: 'details', child: Text('Details')),
                  if (customPlaylistId != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from playlist'),
                    ),
                ],
                icon: const Icon(Icons.more_horiz, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    if (value == 'next' || value == 'queue') {
      final playable = await resolveOne(ref, track);
      if (!context.mounted) return;
      if (playable == null) {
        showNote(context, 'No audio source for ${track.title}.');
        return;
      }
      if (value == 'next') {
        await ref.read(playerProvider).addNext(playable);
      } else {
        await ref.read(playerProvider).enqueue(playable);
      }
      return;
    }
    if (value == 'playlist') {
      if (!context.mounted) return;
      await _addToPlaylist(context, ref);
      return;
    }
    if (value == 'server_link') {
      if (!context.mounted) return;
      await copyServerLink(context, ref, track);
      return;
    }
    if (value == 'pin') {
      final error = await ref
          .read(downloadManagerProvider)
          .pinTrack(track, ref.read(settingsProvider));
      if (!context.mounted) return;
      showNote(context, error ?? 'Pinned ${track.title}.');
      return;
    }
    if (value == 'artist') {
      ref.read(navProvider.notifier).openArtist(track.artist);
      return;
    }
    if (value == 'album') {
      ref.read(navProvider.notifier).openAlbum(albumKeyFor(track));
      return;
    }
    if (value == 'details') {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _DetailsDialog(track: track),
      );
      return;
    }
    if (value == 'remove') {
      final playlistId = customPlaylistId;
      final data = ref.read(userLibraryProvider).valueOrNull;
      final playlist = data?.playlists
          .where((item) => item.id == playlistId)
          .firstOrNull;
      final index = playlist?.trackIds.indexOf(track.id) ?? -1;
      if (playlistId != null && index >= 0) {
        await ref
            .read(userLibraryProvider.notifier)
            .mutate((current) => current.removeTrack(playlistId, index));
      }
    }
  }

  Future<void> _addToPlaylist(BuildContext context, WidgetRef ref) async {
    final data =
        ref.read(userLibraryProvider).valueOrNull ?? UserLibraryData.empty();
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to playlist'),
        children: [
          for (final playlist in data.playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, playlist.id),
              child: Text(playlist.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '__new__'),
            child: const Text('New playlist'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    if (chosen == '__new__') {
      if (!context.mounted) return;
      final name = await promptText(
        context,
        title: 'New playlist',
        confirm: 'Create',
      );
      if (name == null || name.trim().isEmpty) return;
      await ref.read(userLibraryProvider.notifier).mutate((current) {
        final created = current.addPlaylist(name);
        final id = created.playlists.last.id;
        return created.addTrack(id, track.id);
      });
      return;
    }
    await ref
        .read(userLibraryProvider.notifier)
        .mutate((current) => current.addTrack(chosen, track.id));
  }
}

class _ExplicitMark extends StatelessWidget {
  const _ExplicitMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'E',
        style: TextStyle(
          fontSize: 10,
          color: AppColors.sage,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

class _DetailsDialog extends ConsumerWidget {
  const _DetailsDialog({required this.track});

  final TrackRecord track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = track.audioQuality;
    final lines = [
      track.displayArtist,
      if (track.album.isNotEmpty)
        '${track.album}${track.year == null ? '' : ' · ${track.year}'}',
      '${track.durationFormatted} · ${quality.bitrateKbps} kbps · ${quality.sampleRateHz} Hz',
      'Popularity ${formatInt(track.popularity)}',
      if (track.file.relativePath.isNotEmpty) track.file.relativePath,
      if (track.isrc.isNotEmpty) 'ISRC ${track.isrc}',
    ];
    final link = serverLinkFor(track, ref.watch(settingsProvider).cloudBaseUrl);
    return AlertDialog(
      title: Text(track.title, style: Theme.of(context).textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line),
            ),
          if (link != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(link),
            ),
        ],
      ),
      actions: [
        if (link != null)
          GlassActionButton(
            label: 'Copy server link',
            icon: Icons.link_rounded,
            onPressed: () => unawaited(copyServerLink(context, ref, track)),
          ),
        GlassActionButton(
          label: 'Close',
          icon: Icons.close_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

Future<void> copyServerLink(
  BuildContext context,
  WidgetRef ref,
  TrackRecord track,
) async {
  final url = serverLinkFor(track, ref.read(settingsProvider).cloudBaseUrl);
  if (url == null || url.isEmpty) {
    showNote(context, 'No server link for ${track.title}.');
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Copied server link: $url'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        },
      ),
    ),
  );
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirm = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: xernoField('Name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        GlassActionButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryActionPill(
          label: confirm,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    ),
  );
}

/// Release builds subset the icon font to constant [IconData] values.
/// Icons handed to buttons through a field are kept by this list.
class KeptIconGlyphs extends StatelessWidget {
  const KeptIconGlyphs({super.key});

  static const List<IconData> icons = [
    Icons.search_rounded,
    Icons.play_arrow_rounded,
    Icons.shuffle_rounded,
    Icons.arrow_forward_rounded,
    Icons.add_rounded,
    Icons.file_download_outlined,
    Icons.file_upload_outlined,
    Icons.arrow_upward,
    Icons.arrow_downward,
    Icons.delete_outline_rounded,
    Icons.info_outline,
    Icons.skip_next_rounded,
    Icons.skip_previous_rounded,
    Icons.picture_in_picture_alt_rounded,
    Icons.favorite_rounded,
    Icons.favorite_border_rounded,
    Icons.repeat_rounded,
    Icons.repeat_one_rounded,
    Icons.lyrics_outlined,
    Icons.lyrics_rounded,
    Icons.open_in_full_rounded,
    Icons.equalizer_rounded,
    Icons.queue_music_rounded,
    Icons.volume_up_rounded,
    Icons.volume_off_rounded,
    Icons.pause_rounded,
    Icons.keyboard_arrow_down_rounded,
    Icons.tune_rounded,
    Icons.pause_circle_filled_rounded,
    Icons.play_circle_fill_rounded,
    Icons.playlist_remove_rounded,
    Icons.close_rounded,
    Icons.arrow_back_rounded,
    Icons.graphic_eq_rounded,
    Icons.download_rounded,
    Icons.sort_rounded,
    Icons.arrow_upward_rounded,
    Icons.arrow_downward_rounded,
    Icons.drag_indicator,
    Icons.favorite,
    Icons.favorite_border,
    Icons.more_horiz,
    Icons.home_rounded,
    Icons.library_music_rounded,
    Icons.person_rounded,
    Icons.album_rounded,
    Icons.download_done_rounded,
    Icons.home_outlined,
    Icons.search,
    Icons.queue_music_outlined,
    Icons.download_outlined,
    Icons.settings_outlined,
    Icons.refresh_rounded,
    Icons.inventory_2_outlined,
    Icons.folder_open_rounded,
    Icons.sync_rounded,
    Icons.key_rounded,
    Icons.copy_rounded,
    Icons.upload_rounded,
    Icons.visibility_outlined,
    Icons.visibility_off_outlined,
    Icons.link_rounded,
    Icons.login_rounded,
    Icons.person_add_alt_rounded,
    Icons.mark_email_unread_outlined,
    Icons.logout_rounded,
    Icons.merge_type_rounded,
    Icons.swap_horiz_rounded,
    Icons.delete_outline,
    Icons.close,
  ];

  @override
  Widget build(BuildContext context) {
    return _IconAnchor(icons);
  }
}

class _IconAnchor extends StatelessWidget {
  const _IconAnchor(this.icons);

  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return Offstage(child: Text('${icons.length}'));
  }
}
