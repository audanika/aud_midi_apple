// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

@TestOn('mac-os')
library;

import 'dart:async';
import 'dart:math';

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:test/test.dart';

void main() {
  late MidiBonjourBrowserNative browser;
  late List<MidiBonjourEvent> events;
  const type = '_aud-midi-test._udp';

  // Waits up to five seconds until [condition] holds.
  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue);
  }

  setUp(() {
    browser = MidiBonjourBrowserNative();
    events = [];
  });

  tearDown(() => browser.stop());

  group('MidiBonjourBrowserNative', () {
    group('start(type, onEvent)', () {
      test('finds, resolves and loses a service', () async {
        final name = 'aud browser ${Random().nextInt(1 << 30)}';
        browser.start(type, events.add);
        expect(browser.isRunning, isTrue);
        final registration = await const MidiBonjourAdvertiser().register(
          name: name,
          type: type,
          port: 50124,
        );
        await until(
          () => events.any(
            (e) => e.kind == MidiBonjourBrowser.found && e.name == name,
          ),
        );
        final found = events.firstWhere((e) => e.name == name);
        expect(found.host, endsWith('.local.'));
        expect(found.port, 50124);
        await registration.unregister();
        await until(
          () => events.any(
            (e) => e.kind == MidiBonjourBrowser.lost && e.name == name,
          ),
        );
        expect(events.last.host, isEmpty);
      });

      test('runs only once at a time', () {
        browser.start(type, events.add);
        expect(
          () => browser.start(type, events.add),
          throwsA(isA<StateError>()),
        );
      });

      test('throws for an invalid service type', () {
        expect(
          () => browser.start('', events.add),
          throwsA(
            isA<MidiNativeError>().having(
              (e) => e.api,
              'api',
              'DNSServiceBrowse',
            ),
          ),
        );
        expect(browser.isRunning, isFalse);
      });
    });

    group('stop()', () {
      test('does nothing when the browser does not run', () {
        browser
          ..stop()
          ..stop();
        expect(browser.isRunning, isFalse);
      });
    });
  });
}
