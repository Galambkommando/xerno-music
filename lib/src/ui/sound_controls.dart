import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../logic/eq.dart';
import '../models/settings.dart';
import '../platform_info.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

class SoundControls extends ConsumerStatefulWidget {
  const SoundControls({super.key});

  @override
  ConsumerState<SoundControls> createState() => _SoundControlsState();
}

class _SoundControlsState extends ConsumerState<SoundControls> {
  late double _crossfade;
  late double _speed;
  late double _pitch;
  late bool _eqEnabled;
  late String _preset;
  late List<double> _gains;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _crossfade = settings.crossfadeSeconds;
    _speed = settings.speed;
    _pitch = settings.pitch;
    _eqEnabled = settings.eqEnabled;
    _preset = settings.eqPreset;
    _gains = [...settings.eqGains];
    while (_gains.length < 5) {
      _gains.add(0);
    }
    _gains = _gains.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = watchSnapshot(ref);
    final sleepLabel = snapshot.sleepEndOfTrack
        ? 'End of track'
        : snapshot.sleepUntil == null
        ? 'Off'
        : formatClock(snapshot.sleepUntil!.difference(DateTime.now()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crossfade  ${_crossfade.toStringAsFixed(1)}s',
          style: AppTheme.tabular,
        ),
        Slider(
          value: _crossfade,
          min: 0,
          max: 12,
          divisions: 24,
          label: '${_crossfade.toStringAsFixed(1)}s',
          onChanged: (value) => setState(() => _crossfade = value),
          onChangeEnd: (value) => unawaited(_applyCrossfade(value)),
        ),
        Text('Speed  ${_speed.toStringAsFixed(2)}×', style: AppTheme.tabular),
        Slider(
          value: _speed,
          min: 0.5,
          max: 2,
          divisions: 30,
          onChanged: (value) => setState(() => _speed = value),
          onChangeEnd: (value) => unawaited(_applySpeed(value)),
        ),
        Text('Pitch  ${_pitch.toStringAsFixed(2)}', style: AppTheme.tabular),
        Slider(
          value: _pitch,
          min: 0.5,
          max: 1.5,
          divisions: 20,
          onChanged: (value) => setState(() => _pitch = value),
          onChangeEnd: (value) => unawaited(_applyPitch(value)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Equalizer'),
          value: _eqEnabled,
          onChanged: (value) {
            setState(() => _eqEnabled = value);
            unawaited(_applyEq());
          },
        ),
        Wrap(
          children: [
            for (final name in EqSettings.presets.keys)
              ChoicePill(
                label: name,
                selected: _preset == name,
                onTap: () {
                  setState(() {
                    _preset = name;
                    _gains = [...EqSettings.presets[name]!];
                    _eqEnabled = name != 'Flat' || _eqEnabled;
                  });
                  unawaited(_applyEq());
                },
              ),
          ],
        ),
        for (var i = 0; i < 5; i++)
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  EqSettings.bandLabels[i],
                  style: AppTheme.tabular.copyWith(fontSize: 12),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _gains[i].clamp(-12, 12).toDouble(),
                  min: -12,
                  max: 12,
                  divisions: 24,
                  onChanged: (value) => setState(() {
                    _gains[i] = value;
                    _preset = 'Custom';
                  }),
                  onChangeEnd: (_) => unawaited(_applyEq()),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  _gains[i].toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: AppTheme.tabular.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          isAndroidDevice
              ? 'Five bands are applied by the Android equalizer while a track is loaded.'
              : 'Speed, pitch, and crossfade play on this desktop. Five-band settings are stored and applied on Android.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Text('Sleep timer  $sleepLabel', style: AppTheme.tabular),
        const SizedBox(height: 8),
        Wrap(
          children: [
            for (final minutes in const [15, 30, 45, 60])
              ChoicePill(
                label: '${minutes}m',
                selected: false,
                onTap: () => ref.read(playerProvider).setSleepMinutes(minutes),
              ),
            ChoicePill(
              label: 'End of track',
              selected: snapshot.sleepEndOfTrack,
              onTap: () => ref.read(playerProvider).setSleepEndOfTrack(),
            ),
            ChoicePill(
              label: 'Clear',
              selected:
                  snapshot.sleepUntil == null && !snapshot.sleepEndOfTrack,
              onTap: () => ref.read(playerProvider).clearSleep(),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _persist(_SettingsEdit edit) async {
    await ref.read(settingsProvider.notifier).update(edit);
  }

  Future<void> _applyCrossfade(double value) async {
    await ref
        .read(playerProvider)
        .setCrossfade(Duration(milliseconds: (value * 1000).round()));
    await _persist((current) => current.copyWith(crossfadeSeconds: value));
  }

  Future<void> _applySpeed(double value) async {
    await ref.read(playerProvider).setSpeed(value);
    await _persist((current) => current.copyWith(speed: value));
  }

  Future<void> _applyPitch(double value) async {
    await ref.read(playerProvider).setPitch(value);
    await _persist((current) => current.copyWith(pitch: value));
  }

  Future<void> _applyEq() async {
    final settings = EqSettings(
      enabled: _eqEnabled,
      preset: _preset,
      gains: _gains,
    );
    await ref.read(playerProvider).applyEq(settings);
    await _persist(
      (current) => current.copyWith(
        eqEnabled: _eqEnabled,
        eqPreset: _preset,
        eqGains: [..._gains],
      ),
    );
  }
}

typedef _SettingsEdit = AppSettings Function(AppSettings current);
