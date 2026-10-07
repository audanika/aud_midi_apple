// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:test/test.dart';

void main() {
  group('MidiBonjourBrowser', () {
    group('event kinds', () {
      test('match the events of the C shim', () {
        expect([
          MidiBonjourBrowser.found,
          MidiBonjourBrowser.lost,
          MidiBonjourBrowser.failed,
        ], equals([1, 2, 3]));
      });
    });
  });
}
