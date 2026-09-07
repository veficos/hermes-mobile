library;

/// Adaptive speech detector shared by native and web recorders. It learns the
/// ambient floor before arming, then requires sustained energy above both the
/// learned floor and an absolute guard. This avoids treating steady room noise
/// or a short speaker echo as a barge-in.
class VoiceActivityDetector {
  VoiceActivityDetector({
    this.calibration = const Duration(milliseconds: 480),
    this.sustain = const Duration(milliseconds: 280),
    this.minimumStartDb = -34,
    this.floorMarginDb = 11,
  });

  final Duration calibration;
  final Duration sustain;
  final double minimumStartDb;
  final double floorMarginDb;
  DateTime? _startedAt;
  DateTime? _aboveSince;
  double _noiseFloorDb = -60;
  int _floorSamples = 0;

  double get noiseFloorDb => _noiseFloorDb;
  double get startThresholdDb =>
      (_noiseFloorDb + floorMarginDb).clamp(minimumStartDb, -18);
  double get endThresholdDb => (_noiseFloorDb + 6).clamp(-42, -24);

  bool add(double db, DateTime now) {
    final started = _startedAt ??= now;
    if (now.difference(started) < calibration) {
      // Ignore loud calibration outliers (typically the tail of device TTS).
      if (db < -24) {
        _floorSamples++;
        _noiseFloorDb += (db - _noiseFloorDb) / _floorSamples.clamp(1, 24);
      }
      _aboveSince = null;
      return false;
    }
    if (db >= startThresholdDb) {
      _aboveSince ??= now;
      return now.difference(_aboveSince!) >= sustain;
    }
    _aboveSince = null;
    // Slowly track a changing room after calibration, never chasing speech.
    if (db < startThresholdDb - 3) {
      _noiseFloorDb = _noiseFloorDb * 0.96 + db * 0.04;
    }
    return false;
  }
}
