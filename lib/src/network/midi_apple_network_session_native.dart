// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:ffi';

import 'package:objective_c/objective_c.dart' as objc;

import '../native/aud_midi_apple_objc_bindings.g.dart';
import 'midi_apple_network_session.dart';

// #############################################################################
/// The network session of iOS (`MIDINetworkSession`) through Objective-C
/// bindings.
///
/// The macOS SDK declares the class non-functional: `defaultSession` returns
/// nil there, so [isAvailable] is false and macOS sessions are configured in
/// Audio MIDI Setup instead; their endpoints appear as ordinary ports.
final class MidiAppleNetworkSessionNative implements MidiAppleNetworkSession {
  /// Creates the glue; the session is looked up on first use.
  MidiAppleNetworkSessionNative();

  // ...........................................................................
  @override
  bool get isAvailable => _session != null;

  // coverage:ignore-start
  // `+[MIDINetworkSession defaultSession]` is nil on macOS, where these tests
  // run; the members below need the iOS session. Their logic is tested in
  // midi_apple_network_backend_test.dart with a fake session.

  @override
  void setEnabled(bool enabled) => _available.isEnabled = enabled;

  @override
  void setConnectionPolicy(int policy) => _available.connectionPolicy =
      MIDINetworkConnectionPolicy.fromValue(policy);

  @override
  bool addConnection(MidiAppleNetworkHost host) => _available.addConnection(
    MIDINetworkConnection.connectionWithHost(_networkHost(host)),
  );

  @override
  bool removeConnection(MidiAppleNetworkHost host) {
    for (final object in _objects(_available, 'connections')) {
      final connection = MIDINetworkConnection.as(object);
      if (_matches(connection.host, host)) {
        return _available.removeConnection(connection);
      }
    }
    return false;
  }

  @override
  void observe(void Function() onChange) {
    stopObserving();
    final center = NSNotificationCenter.getDefaultCenter();
    final block = ObjCBlock_ffiVoid_NSNotification.listener((_) => onChange());
    _observers.addAll([
      for (final name in [
        MIDINetworkNotificationSessionDidChange,
        MIDINetworkNotificationContactsDidChange,
      ])
        center.addObserverForName(name, usingBlock: block),
    ]);
  }

  @override
  void stopObserving() {
    final center = NSNotificationCenter.getDefaultCenter();
    _observers
      ..forEach(center.removeObserver)
      ..clear();
  }

  @override
  bool get isEnabled => _available.isEnabled;

  @override
  String get networkName => _string(_available, 'networkName');

  @override
  String get localName => _string(_available, 'localName');

  @override
  int get networkPort => _available.networkPort;

  @override
  int get connectionPolicy => _available.connectionPolicy.value;

  @override
  List<MidiAppleNetworkHost> get contacts => [
    for (final object in _objects(_available, 'contacts'))
      _host(MIDINetworkHost.as(object)),
  ];

  @override
  List<MidiAppleNetworkHost> get connections => [
    for (final object in _objects(_available, 'connections'))
      _host(MIDINetworkConnection.as(object).host),
  ];

  @override
  int get sourceEndpoint => _available.sourceEndpoint();

  @override
  int get destinationEndpoint => _available.destinationEndpoint();

  MIDINetworkSession get _available =>
      _session ?? (throw StateError('MIDINetworkSession is not available'));

  static MidiAppleNetworkHost _host(MIDINetworkHost host) => (
    name: _string(host, 'name'),
    address: _string(host, 'address'),
    port: host.port,
    isBonjour: host.netServiceName != null,
  );

  static MIDINetworkHost _networkHost(MidiAppleNetworkHost host) =>
      MIDINetworkHost.hostWithName(
        host.name.toNSString(),
        address: host.address.toNSString(),
        port: host.port,
      );

  static bool _matches(MIDINetworkHost host, MidiAppleNetworkHost other) =>
      _string(host, 'address') == other.address && host.port == other.port;

  /// Returns the string property [selector] of [target], empty for nil.
  ///
  /// The SDK declares these properties non-null, but the session returns
  /// nil while the MIDI server sets it up, which the bindings cannot take.
  static String _string(objc.ObjCObject target, String selector) {
    final string = _send(target.ref.pointer, objc.registerName(selector));
    return string == nullptr
        ? ''
        : objc.NSString.fromPointer(
            string,
            retain: true,
            release: true,
          ).toDartString();
  }

  /// Returns the elements of the set property [selector] of [target], none
  /// for nil.
  static Iterable<objc.ObjCObject> _objects(
    objc.ObjCObject target,
    String selector,
  ) {
    final set = _send(target.ref.pointer, objc.registerName(selector));
    return set == nullptr
        ? const []
        : objc.NSSet.fromPointer(set, retain: true, release: true).asDart();
  }

  static MIDINetworkSession _wrap(Pointer<objc.ObjCObjectImpl> session) =>
      MIDINetworkSession.fromPointer(session, retain: true, release: true);

  // coverage:ignore-end

  // ...........................................................................
  final List<objc.NSObjectProtocol> _observers = [];

  late final MIDINetworkSession? _session = _defaultSession();

  /// Sends `defaultSession` directly, because the generated binding declares
  /// a non-null result, which is wrong on macOS.
  static MIDINetworkSession? _defaultSession() {
    final session = _send(
      objc.getClass('MIDINetworkSession'),
      objc.registerName('defaultSession'),
    );
    return session == nullptr ? null : _wrap(session);
  }

  /// Sends a message without arguments that returns an object or nil.
  static final _send = objc.msgSendPointer
      .cast<
        NativeFunction<
          Pointer<objc.ObjCObjectImpl> Function(
            Pointer<objc.ObjCObjectImpl>,
            Pointer<objc.ObjCSelector>,
          )
        >
      >()
      .asFunction<
        Pointer<objc.ObjCObjectImpl> Function(
          Pointer<objc.ObjCObjectImpl>,
          Pointer<objc.ObjCSelector>,
        )
      >();
}
