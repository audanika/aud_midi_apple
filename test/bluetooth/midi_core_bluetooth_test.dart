// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

void main() {
  group('MidiCoreBluetooth', () {
    group('event kinds', () {
      test('are distinct', () {
        expect({
          MidiCoreBluetooth.stateChanged,
          MidiCoreBluetooth.discovered,
          MidiCoreBluetooth.connected,
          MidiCoreBluetooth.failedToConnect,
          MidiCoreBluetooth.disconnected,
        }, hasLength(5));
      });
    });

    group('states', () {
      test('match CBManagerState', () {
        expect([
          MidiCoreBluetooth.unsupported,
          MidiCoreBluetooth.unauthorized,
          MidiCoreBluetooth.poweredOff,
          MidiCoreBluetooth.poweredOn,
        ], equals([2, 3, 4, 5]));
      });
    });
  });
}
