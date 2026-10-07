// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:ffi/ffi.dart';

import '../native/aud_midi_apple_bindings.g.dart' as native;

// #############################################################################
/// Advertises services through the DNS-SD registrar of macOS and iOS
/// (`DNSServiceRegister` in the C shim).
///
/// On macOS `MIDINetworkSession` does nothing, so a session of the package's
/// own AppleMIDI or Network MIDI 2.0 implementation is announced with this
/// advertiser instead. Registering waits for the registrar for up to
/// [timeout].
final class MidiBonjourAdvertiser implements MidiServiceAdvertiser {
  /// Creates an advertiser that waits up to [timeout] per registration.
  const MidiBonjourAdvertiser({this.timeout = const Duration(seconds: 3)});

  // ...........................................................................
  @override
  Future<MidiServiceRegistration> register({
    required String name,
    required String type,
    required int port,
    Map<String, String> txt = const {},
  }) async => using((arena) {
    final record = txtRecord(txt);
    final bytes = arena<Uint8>(record.length + 1);
    bytes.asTypedList(record.length).setAll(0, record);
    final out = arena<Pointer<native.AudMidiAppleService>>();
    final registeredName = arena<Char>(_nameCapacity);
    final status = native.aud_midi_apple_service_register(
      name.toNativeUtf8(allocator: arena).cast(),
      type.toNativeUtf8(allocator: arena).cast(),
      port,
      bytes,
      record.length,
      timeout.inMilliseconds,
      registeredName,
      _nameCapacity,
      out,
    );
    if (status != 0) {
      throw MidiNativeError(api: 'DNSServiceRegister', code: status);
    }
    return _MidiBonjourRegistration(
      out.value,
      name: registeredName.cast<Utf8>().toDartString(),
    );
  });

  // ...........................................................................
  /// How long a registration waits for the registrar.
  final Duration timeout;

  // ...........................................................................
  /// Returns the DNS-SD TXT record of [entries]: one length-prefixed
  /// `key=value` string per entry (RFC 6763 section 6).
  ///
  /// Throws an [ArgumentError] when an entry is longer than 255 bytes.
  static Uint8List txtRecord(Map<String, String> entries) {
    final record = BytesBuilder();
    for (final MapEntry(:key, :value) in entries.entries) {
      final entry = utf8.encode('$key=$value');
      if (entry.length > 255) {
        throw ArgumentError.value(key, 'txt', 'Entry longer than 255 bytes');
      }
      record
        ..addByte(entry.length)
        ..add(entry);
    }
    return record.takeBytes();
  }

  static const int _nameCapacity = 256;
}

// #############################################################################
final class _MidiBonjourRegistration implements MidiServiceRegistration {
  _MidiBonjourRegistration(this._service, {required this.name});

  @override
  Future<void> unregister() async {
    if (_service == nullptr) return;
    native.aud_midi_apple_service_unregister(_service);
    _service = nullptr;
  }

  @override
  final String name;

  Pointer<native.AudMidiAppleService> _service;
}
