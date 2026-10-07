// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:math';

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:test/test.dart';

void main() {
  group('MidiBonjourAdvertiser', () {
    const advertiser = MidiBonjourAdvertiser();

    group('register(name, type, port, txt)', () {
      test('registers the service until unregister', () async {
        final name = 'aud advertiser ${Random().nextInt(1 << 30)}';
        final registration = await advertiser.register(
          name: name,
          type: '_aud-midi-test._udp',
          port: 50123,
          txt: const {'version': '1'},
        );
        expect(registration.name, name);
        await registration.unregister();
        await registration.unregister();
      });

      test('throws for an invalid service type', () async {
        await expectLater(
          advertiser.register(name: 'aud', type: 'no type', port: 1),
          throwsA(
            isA<MidiNativeError>()
                .having((e) => e.api, 'api', 'DNSServiceRegister')
                .having((e) => e.code, 'code', isNot(0)),
          ),
        );
      });
    });

    group('timeout', () {
      test('defaults to three seconds', () {
        expect(advertiser.timeout, const Duration(seconds: 3));
      });
    });

    group('txtRecord(entries)', () {
      test('prefixes every key=value with its length', () {
        expect(
          MidiBonjourAdvertiser.txtRecord(const {'a': 'b', 'key': 'value'}),
          equals([3, ...utf8.encode('a=b'), 9, ...utf8.encode('key=value')]),
        );
        expect(MidiBonjourAdvertiser.txtRecord(const {}), isEmpty);
      });

      test('throws for entries longer than 255 bytes', () {
        expect(
          () => MidiBonjourAdvertiser.txtRecord({'k': 'v' * 254}),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'txt')),
        );
      });
    });
  });
}
