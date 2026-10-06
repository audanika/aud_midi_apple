# aud_midi_apple

The macOS and iOS backend of aud_midi: CoreMIDI, CoreBluetooth and MIDINetworkSession through FFI.

Part of the aud_midi family, see [aud_midi](https://github.com/audanika/aud_midi).

## Goals

- CoreMIDI ports, virtual endpoints, hotplug, UMP
- BLE MIDI via CoreBluetooth
- MIDINetworkSession
- Small C shim copies packets off CoreMIDI threads

## State

Boilerplate only. The implementation follows in later tickets, see the plan in [aud_midi_pm](https://github.com/audanika/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-06-aud_midi_01-initial-midi-implementation.md).

## Installation

```bash
dart pub add aud_midi_apple
```

## Contributing

See [doc/guides/develop-guide.md](doc/guides/develop-guide.md).
