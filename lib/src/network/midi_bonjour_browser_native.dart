// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:ffi';

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:ffi/ffi.dart';

import '../native/aud_midi_apple_bindings.g.dart' as native;
import 'midi_bonjour_browser.dart';

// #############################################################################
/// Browses with the DNS-SD API of the operating system (`DNSServiceBrowse`
/// and `DNSServiceResolve` in the C shim).
///
/// DNS-SD calls back on a private dispatch queue of the shim, which needs
/// no run loop, unlike `NSNetServiceBrowser`. A service seen on several
/// network interfaces is lost only when it left all of them. On iOS the app
/// declares `_apple-midi._udp` in `NSBonjourServices` and a
/// `NSLocalNetworkUsageDescription`.
final class MidiBonjourBrowserNative implements MidiBonjourBrowser {
  /// Creates a browser; [start] begins browsing.
  MidiBonjourBrowserNative();

  // ...........................................................................
  @override
  void start(String type, void Function(MidiBonjourEvent event) onEvent) {
    if (_browser != nullptr) throw StateError('The browser runs already');
    final callable =
        NativeCallable<
          Void Function(Int32, Pointer<Char>, Pointer<Char>, Int32)
        >.listener((
          int kind,
          Pointer<Char> name,
          Pointer<Char> host,
          int port,
        ) {
          onEvent((
            kind: kind,
            name: _take(name),
            host: _take(host),
            port: port,
          ));
        });
    final status = using((arena) {
      final out = arena<Pointer<native.AudMidiAppleBrowser>>();
      final result = native.aud_midi_apple_browse_start(
        type.toNativeUtf8(allocator: arena).cast(),
        callable.nativeFunction,
        out,
      );
      _browser = out.value;
      return result;
    });
    if (status != 0) {
      callable.close();
      throw MidiNativeError(api: 'DNSServiceBrowse', code: status);
    }
    _callable = callable;
  }

  @override
  void stop() {
    if (_browser == nullptr) return;
    native.aud_midi_apple_browse_stop(_browser);
    _browser = nullptr;
    _callable?.close();
    _callable = null;
  }

  // ...........................................................................
  /// Whether the browser runs.
  bool get isRunning => _browser != nullptr;

  // ...........................................................................
  Pointer<native.AudMidiAppleBrowser> _browser = nullptr;
  NativeCallable<Void Function(Int32, Pointer<Char>, Pointer<Char>, Int32)>?
  _callable;

  /// Returns the string [value] the shim allocated and frees it.
  static String _take(Pointer<Char> value) {
    if (value == nullptr) return '';
    final string = value.cast<Utf8>().toDartString();
    malloc.free(value);
    return string;
  }
}
