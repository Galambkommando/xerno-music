import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../format.dart';
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
    this.playing = false,
    super.key,
  });

  final Lyrics lyrics;
  final Duration position;
  final ValueChanged<Duration> onSeek;
  final bool playing;

  @override
  State<SpicyLyricsPane> createState() => _SpicyLyricsPaneState();
}

class _SpicyLyricsPaneState extends State<SpicyLyricsPane>
    with TickerProviderStateMixin {
  final _keys = <int, GlobalKey>{};
  int _shown = -2;
  late final AnimationController _pulse;
  Ticker? _clock;
  Duration _anchor = Duration.zero;
  DateTime _anchorAt = DateTime.now();
  Duration _paint = Duration.zero;
  bool _userScrolling = false;
  Timer? _scrollCooldown;
  bool _romanize = false;
  bool _translate = false;
  bool _depthBlur = true;
  int? _hover;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anchor = widget.position;
    _paint = widget.position;
    _romanize = widget.lyrics.hasRomanization;
    _syncClock();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
  }

  @override
  void didUpdateWidget(SpicyLyricsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position ||
        oldWidget.playing != widget.playing) {
      _anchor = widget.position;
      _anchorAt = DateTime.now();
      if (!widget.playing) _paint = widget.position;
    }
    if (oldWidget.lyrics != widget.lyrics && !_romanize) {
      _romanize = widget.lyrics.hasRomanization;
    }
    _syncClock();
    _centerActive();
  }

  @override
  void dispose() {
    _clock?.dispose();
    _pulse.dispose();
    _scrollCooldown?.cancel();
    super.dispose();
  }

  void _syncClock() {
    if (!widget.playing) {
      _clock?.stop();
      return;
    }
    _clock ??= createTicker((_) {
      if (!mounted || !widget.playing) return;
      final position = _effective();
      final lines = widget.lyrics.synced;
      final index = lines.isEmpty ? -1 : activeLyricIndex(lines, position);
      if (index != _shown && !_userScrolling) {
        _shown = index;
        _center(index);
      }
      setState(() => _paint = position);
    });
    if (!_clock!.isActive) _clock!.start();
  }

  Duration _effective() {
    if (!widget.playing) return widget.position;
    final extra = DateTime.now().difference(_anchorAt);
    if (extra.isNegative) return _anchor;
    if (extra > const Duration(seconds: 2)) {
      return _anchor + const Duration(seconds: 2);
    }
    return _anchor + extra;
  }

  Duration get _position => widget.playing ? _paint : widget.position;

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  void _centerActive() {
    if (!widget.lyrics.hasSynced || _userScrolling) return;
    final index = activeLyricIndex(widget.lyrics.synced, _position);
    if (index < 0 || index == _shown) return;
    _shown = index;
    _center(index);
  }

  void _center(int index) {
    if (index < 0) return;
    final target = _keyFor(index).currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.42,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _noteScroll(ScrollNotification notice) {
    final fromUser =
        (notice is ScrollStartNotification && notice.dragDetails != null) ||
        (notice is ScrollUpdateNotification && notice.dragDetails != null);
    if (!fromUser && notice is! ScrollEndNotification) return;
    if (fromUser && !_userScrolling) {
      setState(() => _userScrolling = true);
    }
    if (notice is ScrollEndNotification) {
      _scrollCooldown?.cancel();
      _scrollCooldown = Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() => _userScrolling = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    final position = _position;
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
                ? NotificationListener<ScrollNotification>(
                    onNotification: (notice) {
                      _noteScroll(notice);
                      return false;
                    },
                    child: _synced(lyrics, position),
                  )
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
                    child: Text('Lyrics are unavailable for this track yet.'),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        _Controls(
          lyrics: lyrics,
          romanize: _romanize,
          translate: _translate,
          depthBlur: _depthBlur,
          onRomanize: lyrics.hasRomanization
              ? () => setState(() => _romanize = !_romanize)
              : null,
          onTranslate: lyrics.hasTranslation
              ? () => setState(() => _translate = !_translate)
              : null,
          onBlur: () => setState(() => _depthBlur = !_depthBlur),
        ),
      ],
    );
  }

  Widget _synced(Lyrics lyrics, Duration position) {
    final lines = lyrics.synced;
    final active = activeLyricIndex(lines, position);
    final slots = _slots(lines);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 48),
      itemCount: slots.length + (lyrics.songwriters.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (index >= slots.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
            child: Text(
              'Songwriters\n${lyrics.songwriters.join(', ')}',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          );
        }
        final slot = slots[index];
        if (slot.line == null) {
          final span = slot.end - slot.start;
          final into = position - slot.start;
          final progress = span <= Duration.zero
              ? 0.0
              : (into.inMilliseconds / span.inMilliseconds).clamp(0.0, 1.0);
          final here = position >= slot.start && position < slot.end;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: _Dots(pulse: _pulse, progress: here ? progress : 0),
          );
        }
        final lineIndex = slot.line!;
        final line = lines[lineIndex];
        final anchor = active < 0 ? 0 : active;
        final distance = (lineIndex - anchor).abs();
        final current = lineIndex == anchor;
        final recent = active > 0 && lineIndex == active - 1;
        final hovered = _hover == lineIndex;
        final opacity = hovered
            ? 0.92
            : current
            ? 1.0
            : distance == 1
            ? 0.58
            : distance == 2
            ? 0.36
            : 0.22;
        final sigma =
            !_depthBlur || _userScrolling || hovered || current || distance > 3
            ? 0.0
            : math.min(distance * 1.35, 6.5);
        final body = Padding(
          key: _keyFor(lineIndex),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = lineIndex),
            onExit: (_) => setState(() {
              if (_hover == lineIndex) _hover = null;
            }),
            child: GestureDetector(
              onTap: () => widget.onSeek(line.time),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  alignment: line.oppositeTurn
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  scale: hovered ? 1.015 : 1,
                  child: _LineBody(
                    line: line,
                    position: position,
                    detailed: current || recent,
                    romanize: _romanize,
                    translate: _translate,
                    hovered: hovered,
                  ),
                ),
              ),
            ),
          ),
        );
        if (sigma < 0.4) return body;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: body,
        );
      },
    );
  }

  List<_Slot> _slots(List<LyricLine> lines) {
    final slots = <_Slot>[];
    var cursor = Duration.zero;
    for (var i = 0; i < lines.length; i++) {
      final time = lines[i].time;
      if (time - cursor >= const Duration(seconds: 4)) {
        slots.add(_Slot(start: cursor, end: time));
      }
      final end =
          lines[i].end ?? (i + 1 < lines.length ? lines[i + 1].time : time);
      slots.add(_Slot(start: time, end: end, line: i));
      cursor = end > time ? end : time;
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

class _LineBody extends StatelessWidget {
  const _LineBody({
    required this.line,
    required this.position,
    required this.detailed,
    required this.romanize,
    required this.translate,
    required this.hovered,
  });

  final LyricLine line;
  final Duration position;
  final bool detailed;
  final bool romanize;
  final bool translate;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final end = line.oppositeTurn
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final words = line.words.isEmpty
        ? synthesizeWords(
            line.text,
            line.time,
            line.end ?? line.time + const Duration(seconds: 4),
          )
        : line.words;
    final roman =
        distinctLyricNote(line.romanization, line.text) ??
        distinctLyricNote(
          romanizeHangul(line.text) == line.text
              ? null
              : romanizeHangul(line.text),
          line.text,
        );
    final translation = distinctLyricNote(line.translation, line.text);
    final body = Column(
      crossAxisAlignment: end,
      children: [
        if (detailed)
          Wrap(
            alignment: line.oppositeTurn
                ? WrapAlignment.end
                : WrapAlignment.start,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final word in words)
                _SungWord(word: word, position: position),
            ],
          )
        else
          Text(
            line.text,
            textAlign: line.oppositeTurn ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 24,
              height: 1.25,
              color: Colors.white,
            ),
          ),
        if (detailed && line.background.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: line.oppositeTurn
                  ? WrapAlignment.end
                  : WrapAlignment.start,
              spacing: 6,
              children: [
                for (final word in line.background)
                  _SungWord(word: word, position: position, background: true),
              ],
            ),
          ),
        if (romanize && roman != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              roman,
              textAlign: line.oppositeTurn ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
                fontSize: detailed ? 16 : 14,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        if (translate && translation != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              translation,
              textAlign: line.oppositeTurn ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontStyle: FontStyle.italic,
                fontSize: 15,
                color: AppColors.sage,
              ),
            ),
          ),
      ],
    );
    if (!hovered) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: body),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            formatClock(line.time),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: AppColors.ivory,
            ),
          ),
        ),
      ],
    );
  }
}

class _SungWord extends StatelessWidget {
  const _SungWord({
    required this.word,
    required this.position,
    this.background = false,
  });

  final LyricWord word;
  final Duration position;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final progress = _progress(word);
    final atoms = word.pieces.length > 1 ? word.pieces : [word];
    final painted = atoms.length == 1
        ? _glyph(atoms.single)
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final piece in atoms) _glyph(piece)],
          );
    return Transform.translate(
      offset: Offset(0, _lift(progress)),
      child: Transform.scale(
        scale: _scale(progress, word.end - word.start),
        alignment: Alignment.bottomCenter,
        child: painted,
      ),
    );
  }

  double _progress(LyricWord item) {
    final span = item.end - item.start;
    if (span <= Duration.zero) return position >= item.start ? 1 : 0;
    final value = (position - item.start).inMilliseconds / span.inMilliseconds;
    return value.clamp(0.0, 1.0);
  }

  Widget _glyph(LyricWord item) {
    final progress = _progress(item);
    final style = TextStyle(
      fontFamily: 'Outfit',
      fontWeight: background ? FontWeight.w600 : FontWeight.w800,
      fontStyle: background ? FontStyle.italic : FontStyle.normal,
      fontSize: background ? 16 : 32,
      height: 1.15,
      color: Colors.white,
    );
    if (progress <= 0) {
      return Text(
        item.text,
        style: style.copyWith(color: Colors.white.withValues(alpha: 0.38)),
      );
    }
    if (progress >= 1) {
      return Text(
        item.text,
        style: style.copyWith(
          color: Colors.white.withValues(alpha: 0.96),
          shadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.55), blurRadius: 14),
          ],
        ),
      );
    }
    final lead = (progress - 0.15).clamp(0.0, 0.98);
    final tail = (progress + 0.15).clamp(lead + 0.02, 1.0);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        colors: [
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: 0.38),
        ],
        stops: [0, lead, tail],
      ).createShader(rect),
      child: Text(
        item.text,
        style: style.copyWith(
          shadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.78), blurRadius: 18),
          ],
        ),
      ),
    );
  }

  double _lift(double progress) {
    if (progress <= 0) return 2;
    if (progress >= 1) return -1.5;
    if (progress < 0.7) return 2 + (-4.5 - 2) * (progress / 0.7);
    return -4.5 + (-1.5 + 4.5) * ((progress - 0.7) / 0.3);
  }

  double _scale(double progress, Duration span) {
    var scale = 0.97;
    if (progress <= 0) {
      scale = 0.97;
    } else if (progress >= 1) {
      scale = 1;
    } else if (progress < 0.7) {
      scale = 0.97 + (1.045 - 0.97) * (progress / 0.7);
    } else {
      scale = 1.045 + (1 - 1.045) * ((progress - 0.7) / 0.3);
    }
    if (span > const Duration(milliseconds: 900) &&
        progress > 0 &&
        progress < 1) {
      scale += 0.02 * math.sin(progress * math.pi);
    }
    return scale;
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
                padding: const EdgeInsets.only(right: 14),
                child: Transform.translate(
                  offset: Offset(0, progress >= i / 3 ? -3 : 0),
                  child: Transform.scale(
                    scale: progress >= (i + 1) / 3
                        ? 1.08
                        : progress >= i / 3
                        ? 1 + (0.14 * pulse.value)
                        : 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: progress >= i / 3 ? 0.95 : 0.28,
                        ),
                        boxShadow: progress >= i / 3
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
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

class _Controls extends StatelessWidget {
  const _Controls({
    required this.lyrics,
    required this.romanize,
    required this.translate,
    required this.depthBlur,
    required this.onRomanize,
    required this.onTranslate,
    required this.onBlur,
  });

  final Lyrics lyrics;
  final bool romanize;
  final bool translate;
  final bool depthBlur;
  final VoidCallback? onRomanize;
  final VoidCallback? onTranslate;
  final VoidCallback onBlur;

  @override
  Widget build(BuildContext context) {
    final text = lyrics.hasSynced
        ? lyrics.synced.map((line) => line.text).join('\n')
        : lyrics.plain;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Badge(lyrics.sourceLabel),
        if (onRomanize != null)
          _TogglePill(label: 'A/가', selected: romanize, onTap: onRomanize!),
        if (onTranslate != null)
          _TogglePill(label: 'EN', selected: translate, onTap: onTranslate!),
        _TogglePill(label: 'Depth Blur', selected: depthBlur, onTap: onBlur),
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

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? AppColors.mint.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.16),
            ),
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
      ),
    );
  }
}
