// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

void main() {
  group('MidiAppleNetworkSession', () {
    group('policies', () {
      test('match MIDINetworkConnectionPolicy', () {
        expect([
          MidiAppleNetworkSession.noOne,
          MidiAppleNetworkSession.hostsInContactList,
          MidiAppleNetworkSession.anyone,
        ], equals([0, 1, 2]));
      });
    });
  });
}
