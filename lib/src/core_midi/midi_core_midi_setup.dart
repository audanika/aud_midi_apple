// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';

import 'midi_core_midi.dart';

// #############################################################################
/// The ports and devices of a CoreMIDI snapshot, as the package models
/// them.
///
/// Every source becomes an input port and every destination an output port,
/// identified by the endpoint's unique id. Endpoints of devices are grouped
/// device → entity → endpoint; `index` counts the endpoints of one
/// direction across the entities of their device. Offline endpoints stay
/// listed with [MidiPortState.offline], so that a re-plugged device keeps its
/// port ids. Private endpoints are left out. The ports of a device carry its
/// name, model and driver in `native` under the keys of [MidiPortRegistry],
/// from which the engine derives the device.
final class MidiCoreMidiSetup {
  /// Creates an empty setup.
  MidiCoreMidiSetup.empty() : this._(ports: [], devices: [], endpoints: {});

  // ...........................................................................
  /// Maps [snapshot] for the backend named [backend], leaving out the
  /// endpoints in [excluded], e.g. the backend's own virtual endpoints.
  factory MidiCoreMidiSetup.fromSnapshot(
    MidiCoreMidiSnapshot snapshot, {
    required String backend,
    Set<int> excluded = const {},
  }) {
    final mapping = _Mapping(backend: backend, excluded: excluded);
    snapshot.devices.forEach(mapping.addDevice);
    for (final source in snapshot.sources) {
      mapping.addEndpoint(source, direction: MidiDirection.input);
    }
    for (final destination in snapshot.destinations) {
      mapping.addEndpoint(destination, direction: MidiDirection.output);
    }
    return MidiCoreMidiSetup._(
      ports: List.unmodifiable(mapping.ports),
      devices: List.unmodifiable(mapping.devices),
      endpoints: Map.unmodifiable(mapping.endpoints),
    );
  }

  MidiCoreMidiSetup._({
    required this.ports,
    required this.devices,
    required this.endpoints,
  }) : _ports = {for (final port in ports) port.id: port};

  // ...........................................................................
  /// Returns the events that turn [previous] into this setup: removed, then
  /// changed, then added ports.
  List<MidiPortEvent> changesSince(MidiCoreMidiSetup previous) {
    final before = {for (final port in previous.ports) port.id: port};
    final after = {for (final port in ports) port.id: port};
    return [
      for (final port in previous.ports)
        if (!after.containsKey(port.id)) MidiPortRemoved(port: port),
      for (final port in ports)
        if (before[port.id] case final old? when old != port)
          MidiPortChanged(port: port, previous: old),
      for (final port in ports)
        if (!before.containsKey(port.id)) MidiPortAdded(port: port),
    ];
  }

  /// Returns the port [id], or null when the setup has no such port.
  MidiPortInfo? portOf(MidiPortId id) => _ports[id];

  // ...........................................................................
  /// The ports, devices first, then the endpoints of applications.
  final List<MidiPortInfo> ports;

  /// The devices that have at least one port.
  final List<MidiDeviceInfo> devices;

  /// The CoreMIDI endpoint of each port.
  final Map<MidiPortId, MidiCoreMidiEndpoint> endpoints;

  // ...........................................................................
  /// Returns the transport of the CoreMIDI driver [driverOwner], e.g.
  /// `com.apple.AppleMIDIUSBDriver`; an endpoint without driver belongs to
  /// an application.
  static MidiTransport transportOf(String driverOwner) {
    final driver = driverOwner.toLowerCase();
    if (driver.isEmpty) return MidiTransport.virtual;
    if (driver.contains('usb')) return MidiTransport.usb;
    if (driver.contains('bluetooth')) return MidiTransport.bluetoothLe;
    if (driver.contains('network') || driver.contains('rtp')) {
      return MidiTransport.network;
    }
    if (driver.contains('iac')) return MidiTransport.software;
    return MidiTransport.unknown;
  }

  /// Returns the groups whose bits are set in [bitmap] (bit 0 = group 0);
  /// none for null.
  static List<MidiGroupInfo> groupsOf(int? bitmap) => [
    for (var group = 0; group < 16; group++)
      if (bitmap != null && (bitmap >> group) & 1 == 1)
        MidiGroupInfo(group: group),
  ];

  /// Returns the capabilities of a CoreMIDI port: UMP in both directions,
  /// OS timestamps on inputs, CoreMIDI scheduling on outputs.
  ///
  /// No port reports [MidiPortCapabilities.cancelPending]. The only way to
  /// unschedule packets of one destination, `MIDIFlushOutput`, delivers a
  /// System Reset (`0xFF`) to a virtual destination, whether packets were
  /// pending or not, so a synthesizer app would reset at every cancel.
  /// Driver-owned destinations could not be checked, because none was
  /// online on the test machine, so they follow the same rule. The engine
  /// then cancels only its own software queue.
  static MidiPortCapabilities capabilitiesOf({
    required MidiDirection direction,
    required MidiProtocol protocol,
  }) => MidiPortCapabilities(
    timestampsIn: direction == MidiDirection.input,
    scheduledSend: direction == MidiDirection.output,
    ump: true,
    sysEx8: protocol == MidiProtocol.midi2,
  );

  /// Returns the protocol of the CoreMIDI protocol id [protocolId].
  static MidiProtocol protocolOf(int protocolId) =>
      protocolId == 2 ? MidiProtocol.midi2 : MidiProtocol.midi1;

  /// Returns the CoreMIDI protocol id of [protocol].
  static int protocolIdOf(MidiProtocol protocol) =>
      protocol == MidiProtocol.midi2 ? 2 : 1;

  // ...........................................................................
  final Map<MidiPortId, MidiPortInfo> _ports;
}

// #############################################################################
class _Mapping {
  _Mapping({required this.backend, required Set<int> excluded})
    : _seen = {...excluded};

  final String backend;
  final ports = <MidiPortInfo>[];
  final devices = <MidiDeviceInfo>[];
  final endpoints = <MidiPortId, MidiCoreMidiEndpoint>{};
  final Set<int> _seen;

  void addDevice(MidiCoreMidiDevice device) {
    final id = MidiDeviceId.of(
      backend: backend,
      nativeId: '${device.uniqueId}',
    );
    final transport = MidiCoreMidiSetup.transportOf(device.driverOwner);
    final deviceNative = {
      MidiPortRegistry.deviceNameKey: device.name,
      MidiPortRegistry.productKey: device.model,
      MidiPortRegistry.driverKey: device.driverOwner,
    };
    final portIds = <MidiPortId>[];
    var inputs = 0;
    var outputs = 0;
    for (final entity in device.entities) {
      for (final source in entity.sources) {
        final portId = addEndpoint(
          source,
          direction: MidiDirection.input,
          index: inputs++,
          deviceId: id,
          transport: transport,
          deviceNative: deviceNative,
        );
        if (portId != null) portIds.add(portId);
      }
      for (final destination in entity.destinations) {
        final portId = addEndpoint(
          destination,
          direction: MidiDirection.output,
          index: outputs++,
          deviceId: id,
          transport: transport,
          deviceNative: deviceNative,
        );
        if (portId != null) portIds.add(portId);
      }
    }
    if (portIds.isEmpty) return;
    devices.add(
      MidiDeviceInfo(
        id: id,
        name: device.name,
        manufacturer: device.manufacturer,
        product: device.model,
        transport: transport,
        driver: device.driverOwner,
        isOffline: device.isOffline,
        ports: portIds,
        native: {'uniqueId': device.uniqueId},
      ),
    );
  }

  MidiPortId? addEndpoint(
    MidiCoreMidiEndpoint endpoint, {
    required MidiDirection direction,
    int index = 0,
    MidiDeviceId? deviceId,
    MidiTransport? transport,
    Map<String, Object?> deviceNative = const {},
  }) {
    if (endpoint.isPrivate || !_seen.add(endpoint.ref)) return null;
    final id = MidiPortId.of(
      backend: backend,
      nativeId: '${endpoint.uniqueId}',
    );
    if (endpoints.containsKey(id)) return null;
    final protocol = MidiCoreMidiSetup.protocolOf(endpoint.protocol);
    endpoints[id] = endpoint;
    ports.add(
      MidiPortInfo(
        id: id,
        deviceId: deviceId,
        name: endpoint.displayName.isNotEmpty
            ? endpoint.displayName
            : endpoint.name,
        manufacturer: endpoint.manufacturer,
        direction: direction,
        index: index,
        transport:
            transport ?? MidiCoreMidiSetup.transportOf(endpoint.driverOwner),
        protocol: protocol,
        state: endpoint.isOffline
            ? MidiPortState.offline
            : MidiPortState.connected,
        isVirtual: deviceId == null && endpoint.driverOwner.isEmpty,
        groups: MidiCoreMidiSetup.groupsOf(endpoint.groupBitmap),
        capabilities: MidiCoreMidiSetup.capabilitiesOf(
          direction: direction,
          protocol: protocol,
        ),
        native: {
          'uniqueId': endpoint.uniqueId,
          'endpointName': endpoint.name,
          'model': endpoint.model,
          'driverOwner': endpoint.driverOwner,
          ...deviceNative,
        },
      ),
    );
    return id;
  }
}
