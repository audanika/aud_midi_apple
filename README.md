# aud_midi_apple

The macOS and iOS backend of aud_midi: CoreMIDI, CoreBluetooth and MIDINetworkSession through FFI.

Part of the aud_midi family, see [aud_midi](https://github.com/audanika/aud_midi).

## Goals

- CoreMIDI ports, virtual endpoints, hotplug, UMP
- BLE MIDI via CoreBluetooth
- MIDINetworkSession
- Small C shim copies packets off CoreMIDI threads

## State

Boilerplate only. The implementation follows in later tickets, see the plan in [aud_midi](https://github.com/audanika/aud_midi/blob/main/blog/2026/10/01_plan_the_package_implementation.md).

## Installation

```bash
dart pub add aud_midi_apple
```

## Contributing

See [doc/guides/develop-guide.md](doc/guides/develop-guide.md).
