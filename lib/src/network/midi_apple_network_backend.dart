// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';

import 'midi_apple_network_session.dart';
import 'midi_bonjour_browser.dart';

// #############################################################################
/// The network session of iOS (`MIDINetworkSession`, AppleMIDI) as
/// [MidiNetworkBackend].
///
/// The session is one CoreMIDI source and destination shared by all
/// connections; every connection reports their port ids. The operating
/// system names the session after the device and picks its port, so
/// [enable] cannot honour its `name` and `port`; the returned session tells
/// the actual values. Enabling is global state of the device, shared by all
/// apps. [browse] reports the session's contacts and the `_apple-midi._udp`
/// services that Bonjour finds.
final class MidiAppleNetworkBackend implements MidiNetworkBackend {
  /// Creates the backend on top of [networkSession].
  ///
  /// - [browser] creates a Bonjour browser per [browse] call.
  /// - [portsOf] returns the port ids of CoreMIDI endpoints.
  /// - [portTimeout] how long [enable] waits for the session's port.
  MidiAppleNetworkBackend({
    required this.networkSession,
    required this._browser,
    required this._portsOf,
    this.portTimeout = const Duration(seconds: 2),
  });

  // ...........................................................................
  @override
  Future<MidiNetworkSessionInfo> enable({
    required String name,
    int? port,
    MidiNetworkConnectionPolicy policy = MidiNetworkConnectionPolicy.anyone,
  }) async {
    networkSession
      ..setConnectionPolicy(policyValueOf(policy))
      ..setEnabled(true);
    // The session picks its port shortly after it is enabled.
    final waited = Stopwatch()..start();
    while (networkSession.networkPort == 0 && waited.elapsed < portTimeout) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return session;
  }

  @override
  Future<void> disable() async => networkSession.setEnabled(false);

  // ...........................................................................
  /// Adds a connection to [host] to the session.
  ///
  /// Throws a `MidiNativeError` when the session refuses the host.
  @override
  Future<MidiNetworkConnectionInfo> connect(MidiNetworkHostInfo host) async {
    if (!networkSession.addConnection(_appleHost(host))) {
      throw const MidiNativeError(
        api: 'MIDINetworkSession.addConnection',
        code: _refused,
      );
    }
    return _connection(host);
  }

  @override
  Future<void> disconnect(MidiNetworkHostInfo host) async =>
      networkSession.removeConnection(_appleHost(host));

  // ...........................................................................
  /// Reports the contacts of the session and the AppleMIDI sessions Bonjour
  /// finds, after every change; the stream ends when browsing fails.
  @override
  Stream<List<MidiNetworkHostInfo>> browse() {
    final browser = _browser();
    final found = <String, MidiNetworkHostInfo>{};
    late final StreamController<List<MidiNetworkHostInfo>> controller;
    void publish() => controller.add([..._contacts, ...found.values]);
    void onEvent(MidiBonjourEvent event) {
      switch (event.kind) {
        case MidiBonjourBrowser.found:
          found[event.name] = MidiNetworkHostInfo(
            name: event.name,
            address: event.host,
            port: event.port,
            source: MidiNetworkHostSource.bonjour,
          );
        case MidiBonjourBrowser.lost:
          found.remove(event.name);
        default:
          return;
      }
      publish();
    }

    controller = StreamController(
      onListen: () {
        publish();
        try {
          browser.start(MidiNetworkHostInfo.appleMidiServiceType, onEvent);
          _browsers.add(browser);
        } on MidiNativeError {
          unawaited(controller.close());
        }
      },
      onCancel: () {
        browser.stop();
        _browsers.remove(browser);
      },
    );
    return controller.stream;
  }

  // ...........................................................................
  /// Stops observing the session and all browsers.
  void close() {
    networkSession.stopObserving();
    for (final browser in _browsers) {
      browser.stop();
    }
    _browsers.clear();
    unawaited(_changes.close());
  }

  // ...........................................................................
  @override
  MidiNetworkSessionInfo get session => MidiNetworkSessionInfo(
    localName: networkSession.networkName,
    enabled: networkSession.isEnabled,
    port: networkSession.networkPort,
    protocol: MidiNetworkProtocol.appleMidi,
    connectionPolicy: policyOf(networkSession.connectionPolicy),
    connections: [
      for (final host in networkSession.connections)
        _connection(_hostInfo(host)),
    ],
  );

  @override
  Stream<MidiNetworkSessionInfo> get sessionChanges => _changes.stream;

  /// The network session of the operating system.
  final MidiAppleNetworkSession networkSession;

  /// How long [enable] waits for the session's port.
  final Duration portTimeout;

  // ...........................................................................
  /// Returns the policy of the `MIDINetworkConnectionPolicy` [value]; no one
  /// connecting means only the peers the app connects itself.
  static MidiNetworkConnectionPolicy policyOf(int value) => switch (value) {
    MidiAppleNetworkSession.anyone => MidiNetworkConnectionPolicy.anyone,
    MidiAppleNetworkSession.hostsInContactList =>
      MidiNetworkConnectionPolicy.contacts,
    _ => MidiNetworkConnectionPolicy.specificPeers,
  };

  /// Returns the `MIDINetworkConnectionPolicy` value of [policy].
  static int policyValueOf(MidiNetworkConnectionPolicy policy) =>
      switch (policy) {
        MidiNetworkConnectionPolicy.anyone => MidiAppleNetworkSession.anyone,
        MidiNetworkConnectionPolicy.contacts =>
          MidiAppleNetworkSession.hostsInContactList,
        MidiNetworkConnectionPolicy.specificPeers =>
          MidiAppleNetworkSession.noOne,
      };

  // ...........................................................................
  final MidiBonjourBrowser Function() _browser;
  final List<MidiPortId> Function(Set<int> endpoints) _portsOf;
  final _browsers = <MidiBonjourBrowser>{};

  late final StreamController<MidiNetworkSessionInfo> _changes =
      StreamController.broadcast(
        onListen: () => networkSession.observe(() => _changes.add(session)),
        onCancel: networkSession.stopObserving,
      );

  /// The session refused the connection.
  static const int _refused = -1;

  List<MidiNetworkHostInfo> get _contacts => [
    for (final host in networkSession.contacts) _hostInfo(host),
  ];

  MidiNetworkConnectionInfo _connection(MidiNetworkHostInfo host) =>
      MidiNetworkConnectionInfo(
        host: host,
        state: MidiNetworkConnectionState.connected,
        portIds: _portsOf({
          networkSession.sourceEndpoint,
          networkSession.destinationEndpoint,
        }),
      );

  static MidiNetworkHostInfo _hostInfo(MidiAppleNetworkHost host) =>
      MidiNetworkHostInfo(
        name: host.name,
        address: host.address,
        port: host.port,
        source: host.isBonjour
            ? MidiNetworkHostSource.bonjour
            : MidiNetworkHostSource.manual,
      );

  static MidiAppleNetworkHost _appleHost(MidiNetworkHostInfo host) => (
    name: host.name,
    address: host.address,
    port: host.port,
    isBonjour: host.source == MidiNetworkHostSource.bonjour,
  );
}
