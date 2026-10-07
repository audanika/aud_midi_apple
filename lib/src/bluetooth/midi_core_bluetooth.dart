// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// An event of the CoreBluetooth central.
///
/// - `kind` one of [MidiCoreBluetooth.stateChanged] and the other kinds.
/// - `state` the `CBManagerState` for [MidiCoreBluetooth.stateChanged].
/// - `peripheralId` the `NSUUID` of the peripheral, as a string.
/// - `rssi` the signal strength of a discovery in dBm, if known.
/// - `error` the description of the error of a failed or ended connection.
typedef MidiCoreBluetoothEvent = ({
  int kind,
  int state,
  String peripheralId,
  String name,
  int? rssi,
  bool isConnectable,
  String error,
});

// #############################################################################
/// The CoreBluetooth calls of the Bluetooth LE MIDI support: the boundary
/// between the Dart logic and the native layer.
///
/// `MidiCoreBluetoothNative` implements it with Objective-C bindings; tests
/// implement it in Dart.
abstract interface class MidiCoreBluetooth {
  // ...........................................................................
  /// Creates the central; [onEvent] receives its events in the calling
  /// isolate, starting with [stateChanged].
  void open(void Function(MidiCoreBluetoothEvent event) onEvent);

  /// Stops scanning and releases the central.
  void close();

  // ...........................................................................
  /// Scans for peripherals that advertise the BLE-MIDI service.
  void scan();

  /// Stops scanning.
  void stopScan();

  // ...........................................................................
  /// Connects the discovered peripheral [peripheralId].
  void connect(String peripheralId);

  /// Ends the CoreBluetooth connection to [peripheralId].
  void cancelConnection(String peripheralId);

  // ...........................................................................
  /// Whether the user or a policy denied the app the use of Bluetooth;
  /// reading it never prompts.
  bool get isDenied;

  // ...........................................................................
  /// The event of a new central state.
  static const int stateChanged = 0;

  /// The event of a discovered peripheral.
  static const int discovered = 1;

  /// The event of a connected peripheral.
  static const int connected = 2;

  /// The event of a failed connection attempt.
  static const int failedToConnect = 3;

  /// The event of an ended connection.
  static const int disconnected = 4;

  /// `CBManagerStateUnsupported`: the device has no Bluetooth LE.
  static const int unsupported = 2;

  /// `CBManagerStateUnauthorized`: the app may not use Bluetooth.
  static const int unauthorized = 3;

  /// `CBManagerStatePoweredOff`: Bluetooth is switched off.
  static const int poweredOff = 4;

  /// `CBManagerStatePoweredOn`: Bluetooth is ready.
  static const int poweredOn = 5;
}
