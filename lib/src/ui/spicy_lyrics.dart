import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lrc.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';
import 'widgets.dart';

enum LyricsLayout { split, focus, stage }

/// Saturated, slowly drifting copies of the cover, in the Spicy Lyrics style.
class SpicyDynamicBackground extends StatefulWidget {
  const SpicyDynamicBackground({required this.child, this.coverUrl, super.key});

  final Widget child;
  final String? coverUrl;

  @override
  State<SpicyDynamicBackground> createState() => _SpicyDynamicBackgroundState();
}

class _SpicyDynamicBackgroundState extends State<SpicyDynamicBackground>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.coverUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.obsidian),
        if (cover != null && cover.isNotEmpty)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_drift, _breathe]),
              builder: (context, _) {
                final breath = 1.35 + (_breathe.value * 0.12);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _layer(
                      cover,
                      _drift.value,
                      breath,
                      const Alignment(-0.4, -0.2),
                    ),
                    _layer(
                      cover,
                      1 - _drift.value,
                      breath + 0.08,
                      const Alignment(0.45, 0.25),
                    ),
                    _layer(
                      cover,
                      (_drift.value + 0.35) % 1,
                      breath - 0.05,
                      const Alignment(0.1, 0.6),
                    ),
                  ],
                );
              },
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.15,
              colors: [Color(0x22101613), Color(0xCC080B09)],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  Widget _layer(String url, double turns, double scale, Alignment alignment) {
    return Transform.rotate(
      angle: turns * math.pi * 2,
      child: Transform.scale(
        scale: scale,
        alignment: alignment,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_spicyMatrix),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: 160,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// saturate(2.2) then brightness(0.55), matching the Spicy Lyrics cover wash.
const List<double> _spicyMatrix = [
  1.06942,
  -0.4719,
  -0.04752,
  0,
  0,
  -0.14058,
  0.7381,
  -0.04752,
  0,
  0,
  -0.14058,
  -0.4719,
  1.16248,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class SpicyLyricsPane extends StatefulWidget {
  const SpicyLyricsPane({
    required this.lyrics,
    required this.position,
    required this.onSeek,
    super.key,
  });

  final Lyrics lyrics;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  @override
  State<SpicyLyricsPane> createState() => _SpicyLyricsPaneState();
}

class _SpicyLyricsPaneState extends State<SpicyLyricsPane>
    with SingleTickerProviderStateMixin {
  final _keys = <int, GlobalKey>{};
  int _shown = -2;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  @override
  void didUpdateWidget(SpicyLyricsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _center();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  void _center() {
    final lines = widget.lyrics.synced;
    if (!widget.lyrics.hasSynced) return;
    final index = activeLyricIndex(lines, widget.position);
    if (index < 0 || index == _shown) return;
    final target = _keyFor(index).currentContext;
    if (target == null) return;
    _shown = index;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.42,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    return Column(
      children: [
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, 0.12, 0.88, 1],
            ).createShader(rect),
            child: lyrics.instrumental
                ? Center(child: _Dots(pulse: _pulse, progress: 0.4))
                : lyrics.hasSynced
                ? _synced(lyrics.synced)
                : lyrics.plain != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 36, 8, 36),
                    child: Text(
                      lyrics.plain!,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                        height: 1.35,
                        color: AppColors.ivory,
                      ),
                    ),
                  )
                : const Center(
                    child: Text('LRCLIB has no lyrics for this track yet.'),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        _LyricsBadge(lyrics: lyrics),
      ],
    );
  }

  Widget _synced(List<LyricLine> lines) {
    final active = activeLyricIndex(lines, widget.position);
    final slots = _slots(lines);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 48),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        if (slot.line == null) {
          final span = slot.end - slot.start;
          final into = widget.position - slot.start;
          final progress = span <= Duration.zero
              ? 0.0
              : (into.inMilliseconds / span.inMilliseconds).clamp(0.0, 1.0);
          final here =
              widget.position >= slot.start && widget.position < slot.end;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: _Dots(pulse: _pulse, progress: here ? progress : 0),
          );
        }
        final lineIndex = slot.line!;
        final line = lines[lineIndex];
        final distance = active < 0 ? 3 : (lineIndex - active).abs();
        final current = lineIndex == active;
        final progress = current
            ? lyricLineProgress(lines, lineIndex, widget.position)
            : lineIndex < active
            ? 1.0
            : 0.0;
        final opacity = current
            ? 1.0
            : distance == 1
            ? 0.42
            : distance == 2
            ? 0.24
            : 0.14;
        return Padding(
          key: _keyFor(lineIndex),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onSeek(line.time),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  alignment: Alignment.centerLeft,
                  scale: current ? 1.04 : 1,
                  child: _FilledLine(
                    text: line.text,
                    progress: progress,
                    active: current,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<_Slot> _slots(List<LyricLine> lines) {
    final slots = <_Slot>[];
    var cursor = Duration.zero;
    for (var i = 0; i < lines.length; i++) {
      final time = lines[i].time;
      if (time - cursor > const Duration(seconds: 5)) {
        slots.add(_Slot(start: cursor, end: time));
      }
      slots.add(_Slot(start: time, end: time, line: i));
      cursor = time;
    }
    return slots;
  }
}

class _Slot {
  const _Slot({required this.start, required this.end, this.line});

  final Duration start;
  final Duration end;
  final int? line;
}

class _FilledLine extends StatelessWidget {
  const _FilledLine({
    required this.text,
    required this.progress,
    required this.active,
  });

  final String text;
  final double progress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Outfit',
      fontWeight: active ? FontWeight.w800 : FontWeight.w700,
      fontSize: active ? 32 : 24,
      height: 1.25,
      color: Colors.white,
      shadows: active
          ? [
              Shadow(
                color: Colors.white.withValues(alpha: 0.55),
                blurRadius: 18,
              ),
            ]
          : null,
    );
    final line = Text(text, style: style);
    if (!active) return line;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) {
        final cut = progress.clamp(0.001, 0.999);
        return LinearGradient(
          colors: [
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.45),
          ],
          stops: [0, cut, cut, 1],
        ).createShader(rect);
      },
      child: line,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.pulse, required this.progress});

  final Animation<double> pulse;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: i / 3 < progress
                          ? 0.95
                          : 0.28 + (pulse.value * 0.25),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LyricsBadge extends StatelessWidget {
  const _LyricsBadge({required this.lyrics});

  final Lyrics lyrics;

  @override
  Widget build(BuildContext context) {
    final label = lyrics.hasSynced
        ? 'Synced Lyrics · LRCLIB'
        : lyrics.plain != null
        ? 'Static Lyrics'
        : 'Lyrics';
    final text = lyrics.hasSynced
        ? lyrics.synced.map((line) => line.text).join('\n')
        : lyrics.plain;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ivory,
            ),
          ),
        ),
        if (text != null && text.trim().isNotEmpty)
          GlassActionButton(
            label: 'Copy lyrics',
            icon: Icons.copy_rounded,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              showNote(context, 'Copied lyrics');
            },
          ),
      ],
    );
  }
}
