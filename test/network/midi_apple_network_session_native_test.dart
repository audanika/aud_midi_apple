// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

@TestOn('mac-os')
library;

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

void main() {
  group('MidiAppleNetworkSessionNative', () {
    group('isAvailable', () {
      test('is false on macOS, whose defaultSession is nil', () {
        final session = MidiAppleNetworkSessionNative();
        expect(session.isAvailable, isFalse);
        expect(session.isAvailable, isFalse);
      });
    });
  });
}
