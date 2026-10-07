// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

@TestOn('mac-os')
library;

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

// Only the authorization can be read in `dart test`: creating a
// CBCentralManager aborts a process without a Bluetooth usage description.
void main() {
  group('MidiCoreBluetoothNative', () {
    group('isDenied', () {
      test('reads the authorization without prompting', () {
        expect(MidiCoreBluetoothNative().isDenied, isA<bool>());
      });
    });
  });
}
