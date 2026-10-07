// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_apple/aud_midi_apple.dart';
import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:test/test.dart';

void main() {
  MidiCoreMidiEndpoint endpoint(
    int ref, {
    String name = '',
    String displayName = '',
    String manufacturer = '',
    String driverOwner = '',
    bool isOffline = false,
    bool isPrivate = false,
    int protocol = 1,
    int? groupBitmap,
  }) => (
    ref: ref,
    uniqueId: ref * 10,
    name: name,
    displayName: displayName,
    manufacturer: manufacturer,
    model: 'Model',
    driverOwner: driverOwner,
    isOffline: isOffline,
    isPrivate: isPrivate,
    protocol: protocol,
    groupBitmap: groupBitmap,
  );

  const usb = 'com.apple.AppleMIDIUSBDriver';

  final piano = (
    ref: 1,
    uniqueId: 100,
    name: 'Piano',
    manufacturer: 'Roland',
    model: 'RD',
    driverOwner: usb,
    isOffline: false,
    entities: <MidiCoreMidiEntity>[
      (
        name: 'Port 1',
        sources: [
          endpoint(
            2,
            name: 'Port 1',
            displayName: 'Piano Port 1',
            manufacturer: 'Roland',
            driverOwner: usb,
            groupBitmap: 0x5,
          ),
        ],
        destinations: [
          endpoint(3, name: 'Port 1', manufacturer: 'Roland', driverOwner: usb),
        ],
      ),
      (
        name: 'Port 2',
        sources: [endpoint(4, isPrivate: true, driverOwner: usb)],
        destinations: [
          endpoint(
            5,
            displayName: 'Piano Port 2',
            driverOwner: usb,
            isOffline: true,
            protocol: 2,
          ),
        ],
      ),
    ],
  );

  final empty = (
    ref: 6,
    uniqueId: 600,
    name: 'Bluetooth',
    manufacturer: '',
    model: '',
    driverOwner: 'com.apple.AppleMIDIBluetoothDriver',
    isOffline: false,
    entities: <MidiCoreMidiEntity>[],
  );

  final appSource = endpoint(7, name: 'App Out', displayName: 'App Out');

  MidiCoreMidiSetup setupOf({
    List<MidiCoreMidiEndpoint> sources = const [],
    List<MidiCoreMidiEndpoint> destinations = const [],
    Set<int> excluded = const {},
  }) => MidiCoreMidiSetup.fromSnapshot(
    (
      devices: [piano, empty],
      // CoreMIDI lists the online device endpoints here as well.
      sources: [piano.entities.first.sources.single, ...sources],
      destinations: destinations,
    ),
    backend: 'coremidi',
    excluded: excluded,
  );

  group('MidiCoreMidiSetup', () {
    group('empty()', () {
      test('has nothing', () {
        final setup = MidiCoreMidiSetup.empty();
        expect([setup.ports, setup.devices], equals([isEmpty, isEmpty]));
        expect(setup.endpoints, isEmpty);
      });
    });

    group('fromSnapshot(snapshot, backend, excluded)', () {
      test('maps device endpoints to ports with index and state', () {
        final setup = setupOf(
          sources: [appSource],
          destinations: [endpoint(12, name: 'App In')],
        );
        expect(
          setup.ports.map((p) => p.id.value),
          equals([
            'coremidi:20',
            'coremidi:30',
            'coremidi:50',
            'coremidi:70',
            'coremidi:120',
          ]),
        );
        expect(setup.ports.last.direction, MidiDirection.output);
        expect(setup.ports.last.name, 'App In');
        final input = setup.ports[0];
        final device = MidiDeviceId.of(backend: 'coremidi', nativeId: '100');
        expect(input.deviceId, device);
        expect(input.name, 'Piano Port 1');
        expect(input.manufacturer, 'Roland');
        expect(input.direction, MidiDirection.input);
        expect(input.index, 0);
        expect(input.transport, MidiTransport.usb);
        expect(input.state, MidiPortState.connected);
        expect(input.isVirtual, isFalse);
        expect(
          input.groups,
          equals(const [MidiGroupInfo(group: 0), MidiGroupInfo(group: 2)]),
        );
        expect(
          input.native,
          equals({
            'uniqueId': 20,
            'endpointName': 'Port 1',
            'model': 'Model',
            'driverOwner': usb,
            MidiPortRegistry.deviceNameKey: 'Piano',
            MidiPortRegistry.productKey: 'RD',
            MidiPortRegistry.driverKey: usb,
          }),
        );
        expect(setup.ports[1].name, 'Port 1');
        final second = setup.ports[2];
        expect(second.index, 1);
        expect(second.state, MidiPortState.offline);
        expect(second.protocol, MidiProtocol.midi2);
        expect(second.capabilities.sysEx8, isTrue);
        final app = setup.ports[3];
        expect(app.deviceId, isNull);
        expect(app.transport, MidiTransport.virtual);
        expect(app.isVirtual, isTrue);
        expect(
          app.native.keys,
          equals(['uniqueId', 'endpointName', 'model', 'driverOwner']),
        );
        expect(setup.endpoints[app.id], appSource);
      });

      test('lists the devices with ports only', () {
        final setup = setupOf();
        expect(setup.devices, hasLength(1));
        final device = setup.devices.single;
        expect(device.name, 'Piano');
        expect(device.product, 'RD');
        expect(device.driver, usb);
        expect(device.transport, MidiTransport.usb);
        expect(
          device.ports.map((p) => p.value),
          equals(['coremidi:20', 'coremidi:30', 'coremidi:50']),
        );
        expect(device.native['uniqueId'], 100);
      });

      test('leaves out excluded and duplicate endpoints', () {
        final duplicate = endpoint(8);
        final setup = setupOf(
          sources: [appSource, duplicate, duplicate],
          excluded: {7},
        );
        expect(setup.ports.map((p) => p.id.nativeId), isNot(contains('70')));
        expect(setup.ports.where((p) => p.id.nativeId == '80'), hasLength(1));
      });

      test('keeps the first endpoint of a repeated unique id', () {
        final first = endpoint(9, name: 'first');
        const second = (
          ref: 10,
          uniqueId: 90,
          name: 'second',
          displayName: '',
          manufacturer: '',
          model: '',
          driverOwner: '',
          isOffline: false,
          isPrivate: false,
          protocol: 1,
          groupBitmap: null,
        );
        final setup = setupOf(sources: [first, second]);
        expect(
          setup.ports.where((p) => p.id.nativeId == '90').single.name,
          'first',
        );
      });
    });

    group('portOf(id)', () {
      test('finds ports by id', () {
        final setup = setupOf();
        final id = setup.ports.first.id;
        expect(setup.portOf(id), setup.ports.first);
        expect(setup.portOf(const MidiPortId('coremidi:0')), isNull);
      });
    });

    group('changesSince(previous)', () {
      test('reports removed, changed and added ports', () {
        final before = setupOf(sources: [appSource]);
        const renamed = (
          ref: 2,
          uniqueId: 20,
          name: 'Port 1',
          displayName: 'Renamed',
          manufacturer: 'Roland',
          model: 'Model',
          driverOwner: usb,
          isOffline: false,
          isPrivate: false,
          protocol: 1,
          groupBitmap: 0x5,
        );
        final after = MidiCoreMidiSetup.fromSnapshot((
          devices: const [],
          sources: [
            renamed,
            endpoint(11, name: 'New'),
          ],
          destinations: const [],
        ), backend: 'coremidi');
        final events = after.changesSince(before);
        expect(events.map((e) => e.runtimeType), [
          MidiPortRemoved,
          MidiPortRemoved,
          MidiPortRemoved,
          MidiPortChanged,
          MidiPortAdded,
        ]);
        final changed = events[3] as MidiPortChanged;
        expect(changed.previous.name, 'Piano Port 1');
        expect(changed.port.name, 'Renamed');
        expect(events.last.port.name, 'New');
        expect(after.changesSince(after), isEmpty);
      });
    });

    group('transportOf(driverOwner)', () {
      test('maps the drivers of macOS and iOS', () {
        final cases = {
          '': MidiTransport.virtual,
          'com.apple.AppleMIDIUSBDriver': MidiTransport.usb,
          'com.apple.AppleMIDIBluetoothDriver': MidiTransport.bluetoothLe,
          'com.apple.AppleMIDINetworkDriver': MidiTransport.network,
          'com.apple.AppleMIDIRTPDriver': MidiTransport.network,
          'com.apple.AppleMIDIIACDriver': MidiTransport.software,
          'com.example.Driver': MidiTransport.unknown,
        };
        for (final MapEntry(key: driver, value: transport) in cases.entries) {
          expect(
            MidiCoreMidiSetup.transportOf(driver),
            transport,
            reason: driver,
          );
        }
      });
    });

    group('groupsOf(bitmap)', () {
      test('lists the set bits', () {
        expect(MidiCoreMidiSetup.groupsOf(null), isEmpty);
        expect(MidiCoreMidiSetup.groupsOf(0), isEmpty);
        expect(
          MidiCoreMidiSetup.groupsOf(0x8001).map((g) => g.group),
          equals([0, 15]),
        );
      });
    });

    group('capabilitiesOf(direction, protocol)', () {
      test('describes inputs and outputs', () {
        expect(
          MidiCoreMidiSetup.capabilitiesOf(
            direction: MidiDirection.input,
            protocol: MidiProtocol.midi1,
          ),
          const MidiPortCapabilities(timestampsIn: true, ump: true),
        );
        expect(
          MidiCoreMidiSetup.capabilitiesOf(
            direction: MidiDirection.output,
            protocol: MidiProtocol.midi2,
          ),
          const MidiPortCapabilities(
            scheduledSend: true,
            ump: true,
            sysEx8: true,
          ),
        );
      });
    });

    group('protocolOf(id), protocolIdOf(protocol)', () {
      test('convert protocol ids', () {
        expect(MidiCoreMidiSetup.protocolOf(2), MidiProtocol.midi2);
        expect(MidiCoreMidiSetup.protocolOf(1), MidiProtocol.midi1);
        expect(MidiCoreMidiSetup.protocolOf(0), MidiProtocol.midi1);
        expect(MidiCoreMidiSetup.protocolIdOf(MidiProtocol.midi2), 2);
        expect(MidiCoreMidiSetup.protocolIdOf(MidiProtocol.midi1), 1);
      });
    });
  });
}
