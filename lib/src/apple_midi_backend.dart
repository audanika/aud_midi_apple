// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';

import 'bluetooth/midi_apple_bluetooth_backend.dart';
import 'bluetooth/midi_core_bluetooth.dart';
import 'bluetooth/midi_core_bluetooth_native.dart';
import 'core_midi/midi_core_midi.dart';
import 'core_midi/midi_core_midi_native.dart';
import 'core_midi/midi_core_midi_setup.dart';
import 'core_midi/midi_mach_timebase.dart';
import 'network/midi_apple_network_backend.dart';
import 'network/midi_apple_network_session.dart';
import 'network/midi_apple_network_session_native.dart';
import 'network/midi_bonjour_browser.dart';
import 'network/midi_bonjour_browser_native.dart';

// #############################################################################
/// The CoreMIDI backend of macOS and iOS.
///
/// Every CoreMIDI source is an input port and every destination an output
/// port, including the virtual endpoints of other applications. All ports
/// exchange UMP words ([MidiPortCapabilities.ump]) in the protocol of their
/// endpoint, so CoreMIDI never translates. Inputs carry the OS timestamps,
/// outputs hand future packets to the CoreMIDI scheduler. Packets in that
/// scheduler are never cancelled, see [cancelPending].
///
/// The backend creates virtual endpoints itself ([virtualPorts] returns the
/// backend), connects Bluetooth LE MIDI peripherals through CoreBluetooth
/// ([bluetooth], macOS 13 and iOS 16) and controls the network session of
/// iOS ([network]; `MIDINetworkSession` does nothing on macOS, whose
/// sessions are set up in Audio MIDI Setup and appear as ports).
final class AppleMidiBackend implements MidiBackend, MidiVirtualPortsBackend {
  /// Creates the backend; the native layers can be replaced for tests.
  ///
  /// - [clientName] the name of the CoreMIDI client.
  /// - [resyncInterval] how often the mach clock is mapped to the package
  ///   clock again.
  /// - [bluetoothTimeout] how long Bluetooth waits for its power state.
  AppleMidiBackend({
    MidiCoreMidi? coreMidi,
    this._coreBluetooth,
    this._networkSession,
    this._bonjourBrowser,
    this.clientName = 'aud_midi',
    this.resyncInterval = const Duration(seconds: 10),
    this.bluetoothTimeout = const Duration(seconds: 5),
  }) : _coreMidi = coreMidi ?? MidiCoreMidiNative();

  // ...........................................................................
  @override
  Future<void> start(MidiBackendHost host) async {
    if (_host != null) throw StateError('The backend runs already');
    _coreMidi.open(name: clientName, onSignal: _onSignal);
    _host = host;
    _timebase = _coreMidi.timebase;
    _mapper = MidiClockMapper(
      clock: host.clock,
      nativeNow: () => _timebase.toMicros(_coreMidi.now()),
    );
    _setup = _readSetup();
    _resync = Timer.periodic(resyncInterval, (_) => _mapper.resync());
  }

  @override
  Future<void> stop() async {
    if (_host == null) return;
    _resync.cancel();
    _bluetooth?.close();
    _network?.close();
    _bluetooth = null;
    _network = null;
    for (final input in _inputs.values) {
      _quietly(
        () => _coreMidi.disconnectSource(input.ref, protocol: input.protocol),
      );
    }
    for (final own in _own.values) {
      _quietly(() => _coreMidi.disposeEndpoint(own.ref));
    }
    _coreMidi.close();
    for (final waiter in _bluetoothWaiters) {
      waiter.completer.completeError(StateError('The backend stopped'));
    }
    _bluetoothWaiters.clear();
    _inputs.clear();
    _own.clear();
    _receiving.clear();
    _setup = MidiCoreMidiSetup.empty();
    _host = null;
  }

  // ...........................................................................
  @override
  Future<void> openPort(MidiPortId port) async {
    _running;
    final own = _own[port];
    if (own != null) {
      if (own.refCon != null) _receiving[own.refCon!] = port;
      return;
    }
    final info = _setup.portOf(port) ?? (throw MidiPortGone(port));
    if (info.isOutput || _inputs.containsKey(port)) return;
    final ref = _setup.endpoints[port]!.ref;
    final protocol = MidiCoreMidiSetup.protocolIdOf(info.protocol);
    final refCon = _nextRefCon++;
    _coreMidi.connectSource(ref, protocol: protocol, refCon: refCon);
    _inputs[port] = (refCon: refCon, ref: ref, protocol: protocol);
    _receiving[refCon] = port;
  }

  @override
  Future<void> closePort(MidiPortId port) async {
    _running;
    final own = _own[port];
    if (own != null) {
      _receiving.remove(own.refCon);
      return;
    }
    final input = _inputs.remove(port);
    if (input != null) {
      _receiving.remove(input.refCon);
      _quietly(
        () => _coreMidi.disconnectSource(input.ref, protocol: input.protocol),
      );
      return;
    }
    if (_setup.portOf(port) == null) throw MidiPortGone(port);
  }

  // ...........................................................................
  @override
  Future<void> send(MidiPortId port, MidiPacket packet) async {
    _running;
    if (packet is! MidiUmpPacket) {
      throw ArgumentError.value(packet, 'packet', 'CoreMIDI ports take UMPs');
    }
    final (ref, protocol, isOwn) = _output(port);
    final timestamp = _ticksOf(packet.time);
    if (isOwn) {
      _coreMidi.emit(
        ref,
        protocol: protocol,
        timestamp: timestamp,
        words: packet.words,
      );
    } else {
      _coreMidi.send(
        ref,
        protocol: protocol,
        timestamp: timestamp,
        words: packet.words,
      );
    }
  }

  /// Does nothing: no CoreMIDI port supports
  /// [MidiPortCapabilities.cancelPending].
  ///
  /// `MIDIFlushOutput` would unschedule the packets, but it also delivers a
  /// System Reset to virtual destinations, see
  /// [MidiCoreMidiSetup.capabilitiesOf]. Throws a `MidiPortGone` for an
  /// unknown port and a `MidiUnsupported` for an input.
  @override
  Future<void> cancelPending(MidiPortId port) async {
    _running;
    _output(port);
  }

  // ...........................................................................
  @override
  Future<MidiPortInfo> create(MidiVirtualPortSpec spec) async {
    final host = _running;
    final protocol = MidiCoreMidiSetup.protocolIdOf(spec.protocol);
    final isSource = spec.direction == MidiDirection.output;
    final refCon = isSource ? null : _nextRefCon++;
    final ref = isSource
        ? _coreMidi.createSource(name: spec.name, protocol: protocol)
        : _coreMidi.createDestination(
            name: spec.name,
            protocol: protocol,
            refCon: refCon!,
          );
    try {
      _coreMidi.describe(
        ref,
        uniqueId: spec.uniqueId,
        manufacturer: spec.manufacturer.isEmpty ? null : spec.manufacturer,
        model: spec.model.isEmpty ? null : spec.model,
        groupBitmap: spec.groups.isEmpty
            ? null
            : spec.groups.fold<int>(0, (bits, group) => bits | 1 << group),
      );
    } on MidiNativeError {
      _quietly(() => _coreMidi.disposeEndpoint(ref));
      rethrow;
    }
    final port = _ownPort(spec, uniqueId: _coreMidi.uniqueIdOf(ref));
    _own[port.id] = (port: port, ref: ref, protocol: protocol, refCon: refCon);
    host.portsChanged([MidiPortAdded(port: port)]);
    return port;
  }

  @override
  Future<void> remove(MidiPortId port) async {
    final host = _running;
    final own = _own.remove(port);
    if (own == null) {
      if (_setup.portOf(port) == null) throw MidiPortGone(port);
      throw const MidiUnsupported('removing a port of another client');
    }
    _receiving.remove(own.refCon);
    _coreMidi.disposeEndpoint(own.ref);
    host.portsChanged([MidiPortRemoved(port: own.port)]);
  }

  // ...........................................................................
  /// Rereads all CoreMIDI devices and endpoints and reports the changes, as
  /// after a CoreMIDI notification.
  void refresh() {
    final host = _running;
    final previous = _setup;
    _setup = _readSetup();
    _reconnectInputs();
    _mapper.resync();
    final events = _setup.changesSince(previous);
    if (events.isNotEmpty) host.portsChanged(events);
    _serveBluetoothWaiters();
  }

  // ...........................................................................
  @override
  String get name => 'coremidi';

  @override
  MidiCapabilities get capabilities => MidiCapabilities(
    virtualPorts: MidiVirtualPortSupport.dynamicPorts,
    bleScan: bluetooth != null,
    network: {if (network != null) MidiNetworkSupport.osSession},
    ump: true,
    scheduling: MidiSchedulingSupport.hardware,
    missingPermissions: {
      if (_bluetoothBackend()?.central.isDenied ?? false)
        MidiPermission.bluetooth,
    },
  );

  @override
  List<MidiPortInfo> get ports => [
    ..._setup.ports,
    for (final own in _own.values) own.port,
  ];

  /// The devices that have ports; the own virtual ports belong to none.
  List<MidiDeviceInfo> get devices => _setup.devices;

  @override
  MidiVirtualPortsBackend get virtualPorts => this;

  @override
  MidiBluetoothBackend? get bluetooth => _bluetoothBackend();

  @override
  MidiNetworkBackend? get network => _network ??= _networkBackend();

  // ...........................................................................
  /// The name of the CoreMIDI client.
  final String clientName;

  /// How often the mach clock is mapped to the package clock again.
  final Duration resyncInterval;

  /// How long Bluetooth waits for its power state.
  final Duration bluetoothTimeout;

  // ...........................................................................
  final MidiCoreMidi _coreMidi;
  final MidiCoreBluetooth? _coreBluetooth;
  final MidiAppleNetworkSession? _networkSession;
  final MidiBonjourBrowser Function()? _bonjourBrowser;

  MidiBackendHost? _host;
  late MidiMachTimebase _timebase;
  late MidiClockMapper _mapper;
  late Timer _resync;
  MidiCoreMidiSetup _setup = MidiCoreMidiSetup.empty();
  MidiAppleBluetoothBackend? _bluetooth;
  MidiAppleNetworkBackend? _network;
  MidiAppleNetworkSession? _networkSessionApi;
  int _nextRefCon = 1;

  final _inputs = <MidiPortId, ({int refCon, int ref, int protocol})>{};
  final _own =
      <MidiPortId, ({MidiPortInfo port, int ref, int protocol, int? refCon})>{};
  final _receiving = <int, MidiPortId>{};
  final _bluetoothWaiters =
      <({String name, Completer<List<MidiPortInfo>> completer})>[];

  MidiBackendHost get _running =>
      _host ?? (throw StateError('The backend is not running'));

  MidiCoreMidiSetup _readSetup() => MidiCoreMidiSetup.fromSnapshot(
    _coreMidi.snapshot(),
    backend: name,
    excluded: {for (final own in _own.values) own.ref},
  );

  /// Returns the endpoint, the protocol id and the ownership of the output
  /// [port].
  (int, int, bool) _output(MidiPortId port) {
    final own = _own[port];
    if (own != null) {
      if (own.port.isInput) throw const MidiUnsupported('sending to an input');
      return (own.ref, own.protocol, true);
    }
    final info = _setup.portOf(port) ?? (throw MidiPortGone(port));
    if (info.isInput) throw const MidiUnsupported('sending to an input');
    final protocol = MidiCoreMidiSetup.protocolIdOf(info.protocol);
    return (_setup.endpoints[port]!.ref, protocol, false);
  }

  /// Returns the mach ticks of [time]; 0 (now) for a time not in the future.
  int _ticksOf(MidiTime time) => time.isAfter(_running.clock.now())
      ? _timebase.toTicks(_mapper.toNative(time))
      : 0;

  MidiPortInfo _ownPort(MidiVirtualPortSpec spec, {required int uniqueId}) =>
      MidiPortInfo(
        id: MidiPortId.of(backend: name, nativeId: '$uniqueId'),
        name: spec.name,
        manufacturer: spec.manufacturer,
        direction: spec.direction,
        transport: MidiTransport.virtual,
        protocol: spec.protocol,
        isVirtual: true,
        isOwn: true,
        groups: [for (final group in spec.groups) MidiGroupInfo(group: group)],
        capabilities: MidiPortCapabilities(
          timestampsIn: spec.direction == MidiDirection.input,
          ump: true,
          sysEx8: spec.protocol == MidiProtocol.midi2,
        ),
        native: {'uniqueId': uniqueId, 'model': spec.model},
      );

  void _onSignal(int signals) {
    if (_host == null) return;
    if (signals & MidiCoreMidi.packetsSignal != 0) _deliverPackets();
    if (signals & MidiCoreMidi.notificationsSignal != 0) _handleNotifications();
  }

  void _deliverPackets() {
    final host = _running;
    for (final packet in _coreMidi.readPackets()) {
      final port = _receiving[packet.refCon];
      if (port == null) continue;
      final time = _mapper.toPackage(_timebase.toMicros(packet.timestamp));
      host.received(port, MidiUmpPacket(words: packet.words, time: time));
    }
    final dropped = _coreMidi.takeDropped();
    if (dropped == 0) return;
    host.diagnostic(
      MidiDiagnostic(
        kind: MidiDiagnosticKind.queueOverflow,
        count: dropped,
        cause: 'The CoreMIDI receive buffer was full',
        time: host.clock.now(),
      ),
    );
  }

  void _handleNotifications() {
    final host = _running;
    var changed = false;
    for (final notification in _coreMidi.readNotifications()) {
      if (notification.messageId == MidiCoreMidi.ioError) {
        host.diagnostic(
          MidiDiagnostic(
            kind: MidiDiagnosticKind.nativeError,
            cause:
                'CoreMIDI I/O error ${notification.values[1].toSigned(32)} '
                'of device ${notification.values[0]}',
            time: host.clock.now(),
          ),
        );
      }
      changed |= notification.messageId <= MidiCoreMidi.propertyChanged;
    }
    if (changed) refresh();
  }

  /// Connects open inputs again whose endpoint or protocol changed, e.g.
  /// after an application recreated its virtual source.
  void _reconnectInputs() {
    for (final MapEntry(key: port, value: input) in _inputs.entries.toList()) {
      final endpoint = _setup.endpoints[port];
      if (endpoint == null) continue;
      final protocol = MidiCoreMidiSetup.protocolIdOf(
        _setup.portOf(port)!.protocol,
      );
      if (endpoint.ref == input.ref && protocol == input.protocol) continue;
      _quietly(
        () => _coreMidi.disconnectSource(input.ref, protocol: input.protocol),
      );
      try {
        _coreMidi.connectSource(
          endpoint.ref,
          protocol: protocol,
          refCon: input.refCon,
        );
        _inputs[port] = (
          refCon: input.refCon,
          ref: endpoint.ref,
          protocol: protocol,
        );
      } on MidiNativeError catch (error) {
        _running.diagnostic(
          MidiDiagnostic(
            kind: MidiDiagnosticKind.nativeError,
            port: port,
            cause: error.message,
            time: _running.clock.now(),
          ),
        );
      }
    }
  }

  MidiAppleBluetoothBackend? _bluetoothBackend() {
    if (_bluetooth != null) return _bluetooth;
    if (!_coreMidi.bluetoothDriverAvailable) return null;
    return _bluetooth = MidiAppleBluetoothBackend(
      central: _coreBluetooth ?? MidiCoreBluetoothNative(),
      activate: _coreMidi.activateBluetoothConnections,
      disconnectDriver: _coreMidi.disconnectBluetooth,
      waitForPorts: _waitForBluetoothPorts,
      readyTimeout: bluetoothTimeout,
    );
  }

  MidiAppleNetworkBackend? _networkBackend() {
    final session = _networkSessionApi ??=
        _networkSession ?? MidiAppleNetworkSessionNative();
    if (!session.isAvailable) return null;
    return MidiAppleNetworkBackend(
      networkSession: session,
      browser: _bonjourBrowser ?? MidiBonjourBrowserNative.new,
      portsOf: _portsOfEndpoints,
    );
  }

  /// Returns the ids of the ports of the CoreMIDI [endpoints].
  List<MidiPortId> _portsOfEndpoints(Set<int> endpoints) => [
    for (final MapEntry(key: port, value: endpoint) in _setup.endpoints.entries)
      if (endpoints.contains(endpoint.ref)) port,
  ];

  Future<List<MidiPortInfo>> _waitForBluetoothPorts({
    required String name,
    required Duration timeout,
  }) {
    final completer = Completer<List<MidiPortInfo>>();
    final waiter = (name: name, completer: completer);
    _bluetoothWaiters.add(waiter);
    _serveBluetoothWaiters();
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _bluetoothWaiters.remove(waiter);
        throw const MidiNativeError(
          api: 'MIDIBluetoothDriverActivateAllConnections',
          code: _objectNotFound,
        );
      },
    );
  }

  /// Completes the waiters whose Bluetooth device is online with ports.
  void _serveBluetoothWaiters() {
    for (final waiter in _bluetoothWaiters.toList()) {
      final ports = [
        for (final device in _setup.devices)
          if (device.transport == MidiTransport.bluetoothLe &&
              !device.isOffline &&
              (waiter.name.isEmpty || device.name == waiter.name))
            for (final port in device.ports) _setup.portOf(port)!,
      ];
      if (ports.isEmpty) continue;
      _bluetoothWaiters.remove(waiter);
      waiter.completer.complete(ports);
    }
  }

  /// Runs [call] and ignores its native error; used while tearing down.
  static void _quietly(void Function() call) {
    try {
      call();
    } on MidiNativeError {
      // The endpoint is gone already.
    }
  }

  /// `kMIDIObjectNotFound`.
  static const int _objectNotFound = -10842;
}
