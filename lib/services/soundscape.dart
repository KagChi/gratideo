import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class SoundMode {
  const SoundMode(this.id, this.name, this.short, this.about, this.file);
  final String id;
  final String name;
  final String short;
  final String about;
  final String file; // without extension
}

const soundModes = [
  SoundMode('rain', 'Gentle Rain & Stream', 'Rain', 'Soft brown and pink noise with a slow, flowing resonance.', 'gentle-rain-and-stream'),
  SoundMode('drone', 'Deep Solitude', 'Solitude', 'A warm harmonic pad tuned to 432 Hz.', 'deep-solitude-432'),
  SoundMode('meadow', 'Morning Meadow & Gentle Wind', 'Meadow', 'Wind, distant birds and a soft binaural hum. Best with headphones.', 'morning-meadow-wind'),
];

/// One looping player that keeps going across screens and in the background.
/// Sounds are bundled 60-second seamless loops; nothing is streamed.
class Soundscape extends ChangeNotifier {
  Soundscape._();
  static final Soundscape instance = Soundscape._();

  final _player = AudioPlayer();
  String modeId = 'rain';
  double volume = 0.55;
  bool get playing => _player.playing;

  Future<void> init({required String modeId, required double volume}) async {
    this.modeId = modeId;
    this.volume = volume;
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(_curve(volume));
    _player.playingStream.listen((_) => notifyListeners());
    await _load(modeId);
  }

  SoundMode get mode => soundModes.firstWhere((m) => m.id == modeId, orElse: () => soundModes.first);

  Future<void> _load(String id) async {
    final m = soundModes.firstWhere((x) => x.id == id);
    final ext = Platform.isIOS || Platform.isMacOS ? 'm4a' : 'ogg';
    await _player.setAudioSource(AudioSource.asset(
      'assets/audio/${m.file}.$ext',
      tag: MediaItem(id: m.id, title: m.name, album: 'Gratideo soundscape'),
    ));
  }

  Future<void> play() async {
    await _fadeTo(_curve(volume), const Duration(milliseconds: 500), start: 0);
    unawaited(_player.play());
    notifyListeners();
  }

  Future<void> pause() async {
    await _fadeTo(0, const Duration(milliseconds: 350));
    await _player.pause();
    await _player.setVolume(_curve(volume));
    notifyListeners();
  }

  Future<void> toggle() => playing ? pause() : play();

  /// Switch sounds with a short fade so there is no hard cut.
  Future<void> setMode(String id) async {
    if (id == modeId) return;
    final wasPlaying = playing;
    if (wasPlaying) await _fadeTo(0, const Duration(milliseconds: 500));
    modeId = id;
    await _load(id);
    if (wasPlaying) {
      unawaited(_player.play());
      await _fadeTo(_curve(volume), const Duration(milliseconds: 700), start: 0);
    }
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0, 1);
    await _player.setVolume(_curve(volume));
    notifyListeners();
  }

  double _curve(double v) => v * v * 0.9; // perceptual taper

  Future<void> _fadeTo(double target, Duration d, {double? start}) async {
    final from = start ?? _player.volume;
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await _player.setVolume(from + (target - from) * i / steps);
      await Future<void>.delayed(d ~/ steps);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
