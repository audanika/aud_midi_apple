# aud_midi_apple

Das macOS- und iOS-Backend von aud_midi: CoreMIDI, CoreBluetooth und MIDINetworkSession über FFI.

Teil der aud_midi-Familie, siehe [aud_midi](https://github.com/audanika/aud_midi).

## Ziele

- CoreMIDI-Ports, virtuelle Endpoints, Hotplug, UMP
- BLE-MIDI über CoreBluetooth
- MIDINetworkSession
- Kleiner C-Shim kopiert Pakete von den CoreMIDI-Threads

## Stand

Nur Boilerplate. Die Implementierung folgt in späteren Tickets, siehe den Plan in [aud_midi](https://github.com/audanika/aud_midi/blob/main/blog/2026/10/01_plan_the_package_implementation.md).

## Installation

```bash
dart pub add aud_midi_apple
```

## Mitwirken

Siehe [doc/guides/develop-guide.md](doc/guides/develop-guide.md).
