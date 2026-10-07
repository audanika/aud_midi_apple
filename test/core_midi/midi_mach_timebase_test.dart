// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

void main() {
  group('MidiMachTimebase', () {
    const appleSilicon = MidiMachTimebase(numer: 125, denom: 3);
    const intel = MidiMachTimebase(numer: 1, denom: 1);

    group('toMicros(ticks)', () {
      test('converts ticks of 125/3 ns and 1 ns', () {
        expect(appleSilicon.toMicros(24), 1);
        expect(appleSilicon.toMicros(24000000), 1000000);
        expect(intel.toMicros(1000), 1);
        expect(intel.toMicros(1999), 1);
      });

      test('does not overflow for a year of ticks', () {
        const year = 24000000 * 3600 * 24 * 365;
        expect(appleSilicon.toMicros(year), 1000000 * 3600 * 24 * 365);
      });

      test('returns 0 for 0 and negative ticks', () {
        for (final ticks in [0, -1]) {
          expect(appleSilicon.toMicros(ticks), 0, reason: '$ticks');
        }
      });
    });

    group('toTicks(micros)', () {
      test('converts microseconds back', () {
        expect(appleSilicon.toTicks(1), 24);
        expect(appleSilicon.toTicks(1000000), 24000000);
        expect(intel.toTicks(7), 7000);
        for (final micros in [1, 999, 123456789]) {
          expect(
            appleSilicon.toMicros(appleSilicon.toTicks(micros)),
            micros,
            reason: '$micros',
          );
        }
      });

      test('returns 0 for 0 and negative microseconds', () {
        for (final micros in [0, -5]) {
          expect(intel.toTicks(micros), 0, reason: '$micros');
        }
      });
    });

    group('numer, denom', () {
      test('keep the tick duration', () {
        expect([intel.numer, intel.denom], equals([1, 1]));
      });
    });
  });
}
