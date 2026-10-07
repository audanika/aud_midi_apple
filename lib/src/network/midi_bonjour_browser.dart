// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// A Bonjour browse event.
///
/// - `kind` [MidiBonjourBrowser.found], [MidiBonjourBrowser.lost] or
///   [MidiBonjourBrowser.failed].
/// - `name` the service name; empty for [MidiBonjourBrowser.failed].
/// - `host` the host name of a found service, e.g. `studio.local.`.
/// - `port` the port of a found service, or the DNS-SD error of a failure.
typedef MidiBonjourEvent = ({int kind, String name, String host, int port});

// #############################################################################
/// Browses the local network for DNS-SD services: the boundary between the
/// network logic and the native layer.
///
/// `MidiBonjourBrowserNative` implements it with the DNS-SD API of the C
/// shim; tests implement it in Dart.
abstract interface class MidiBonjourBrowser {
  // ...........................................................................
  /// Starts browsing for services of [type], e.g. `_apple-midi._udp`;
  /// [onEvent] receives the events in the calling isolate.
  void start(String type, void Function(MidiBonjourEvent event) onEvent);

  /// Stops browsing; no event arrives afterwards.
  void stop();

  // ...........................................................................
  /// A service was found and resolved to host and port.
  static const int found = 1;

  /// A service disappeared.
  static const int lost = 2;

  /// Browsing failed.
  static const int failed = 3;
}
