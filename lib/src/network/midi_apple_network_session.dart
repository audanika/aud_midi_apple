// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// A host of `MIDINetworkSession`: its name, its address or host name and
/// its UDP control port.
///
/// - `isBonjour` whether the host came from Bonjour (it carries a net
///   service name) instead of an address entered by hand.
typedef MidiAppleNetworkHost = ({
  String name,
  String address,
  int port,
  bool isBonjour,
});

// #############################################################################
/// The calls of the network session (`MIDINetworkSession`): the boundary
/// between the network logic and the native layer.
///
/// `MidiAppleNetworkSessionNative` implements it with Objective-C bindings;
/// tests implement it in Dart. Only iOS provides the session; on macOS
/// [isAvailable] is false and sessions are set up in Audio MIDI Setup.
abstract interface class MidiAppleNetworkSession {
  // ...........................................................................
  /// Whether the operating system provides the session.
  bool get isAvailable;

  // ...........................................................................
  /// Enables or disables the session for all apps of the device.
  void setEnabled(bool enabled);

  /// Sets who may connect, as `MIDINetworkConnectionPolicy` value.
  void setConnectionPolicy(int policy);

  /// Adds a connection to [host]; returns whether the session took it.
  bool addConnection(MidiAppleNetworkHost host);

  /// Removes the connection to [host]; returns whether the session had it.
  bool removeConnection(MidiAppleNetworkHost host);

  // ...........................................................................
  /// Calls [onChange] in the calling isolate whenever the session or its
  /// contacts change, until [stopObserving].
  void observe(void Function() onChange);

  /// Stops calling the observer.
  void stopObserving();

  // ...........................................................................
  /// Whether the session is enabled.
  bool get isEnabled;

  /// The name under which Bonjour announces the session.
  String get networkName;

  /// The name of the session's CoreMIDI entity.
  String get localName;

  /// The UDP control port of the session.
  int get networkPort;

  /// Who may connect, as `MIDINetworkConnectionPolicy` value.
  int get connectionPolicy;

  /// The hosts of the contact list.
  List<MidiAppleNetworkHost> get contacts;

  /// The hosts the session is connected to.
  List<MidiAppleNetworkHost> get connections;

  /// The CoreMIDI source of the session.
  int get sourceEndpoint;

  /// The CoreMIDI destination of the session.
  int get destinationEndpoint;

  // ...........................................................................
  /// `MIDINetworkConnectionPolicy_NoOne`.
  static const int noOne = 0;

  /// `MIDINetworkConnectionPolicy_HostsInContactList`.
  static const int hostsInContactList = 1;

  /// `MIDINetworkConnectionPolicy_Anyone`.
  static const int anyone = 2;
}
