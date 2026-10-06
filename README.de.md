# aud_midi_apple

Das macOS- und iOS-Backend von aud_midi: CoreMIDI, CoreBluetooth und MIDINetworkSession über FFI.

Teil der aud_midi-Familie, siehe [aud_midi](https://github.com/audanika/aud_midi).

## Ziele

- CoreMIDI-Ports, virtuelle Endpoints, Hotplug, UMP
- BLE-MIDI über CoreBluetooth
- MIDINetworkSession
- Kleiner C-Shim kopiert Pakete von den CoreMIDI-Threads
- BLE-Peripheral über CBPeripheralManager

## Stand

Nur Boilerplate. Die Implementierung folgt in späteren Tickets, siehe den Plan in [aud_midi_pm](https://github.com/audanika/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-06-aud_midi_01-initial-midi-implementation.md).

## Installation

```bash
dart pub add aud_midi_apple
```

## Mitwirken

Siehe [doc/guides/develop-guide.md](doc/guides/develop-guide.md).
