// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

void main() {
  group('MidiCoreMidi', () {
    group('signals', () {
      test('are distinct bits', () {
        expect(
          MidiCoreMidi.packetsSignal & MidiCoreMidi.notificationsSignal,
          0,
        );
      });
    });

    group('notification ids', () {
      test('match MIDINotificationMessageID', () {
        expect([
          MidiCoreMidi.notificationsLost,
          MidiCoreMidi.setupChanged,
          MidiCoreMidi.objectAdded,
          MidiCoreMidi.objectRemoved,
          MidiCoreMidi.propertyChanged,
          MidiCoreMidi.ioError,
        ], equals([0, 1, 2, 3, 4, 7]));
      });
    });
  });
}
