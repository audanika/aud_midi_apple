// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// Converts mach absolute time ticks, the clock of CoreMIDI timestamps
/// (`MIDITimeStamp`), to microseconds and back.
///
/// One tick lasts [numer] / [denom] nanoseconds (`mach_timebase_info`),
/// e.g. 125 / 3 on Apple silicon and 1 / 1 on Intel. The conversions split
/// the multiplication so that it never overflows 64 bits.
final class MidiMachTimebase {
  /// Creates the timebase of ticks lasting [numer] / [denom] nanoseconds.
  const MidiMachTimebase({required this.numer, required this.denom})
    : assert(numer > 0 && denom > 0);

  // ...........................................................................
  /// Returns [ticks] in microseconds; 0 for ticks of 0 or less.
  int toMicros(int ticks) {
    if (ticks <= 0) return 0;
    final nanos = (ticks ~/ denom) * numer + (ticks % denom) * numer ~/ denom;
    return nanos ~/ 1000;
  }

  /// Returns [micros] in ticks; 0 for microseconds of 0 or less.
  int toTicks(int micros) {
    if (micros <= 0) return 0;
    final nanos = micros * 1000;
    return (nanos ~/ numer) * denom + (nanos % numer) * denom ~/ numer;
  }

  // ...........................................................................
  /// The numerator of the tick duration in nanoseconds.
  final int numer;

  /// The denominator of the tick duration in nanoseconds.
  final int denom;
}
