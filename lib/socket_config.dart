/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:io';

class SocketConfig {
  final InternetAddress address;
  final int port;
  final int connectionCheckIntervalSeconds;
  final String? privateKeyPath;

  SocketConfig({
    required this.address,
    required this.port,
    required this.connectionCheckIntervalSeconds,
    required this.privateKeyPath,
  });

  SocketConfig.withEnvironment({
    InternetAddress? address,
    int? port,
    int? connectionCheckIntervalSeconds,
    String? privateKeyPath,
  })  : address = address ?? _defaultAddress(),
        port = port ?? _defaultNumber('IRCD_PORT', 6667),
        connectionCheckIntervalSeconds = connectionCheckIntervalSeconds ??
            _defaultNumber('IRCD_CONN_CHECK_INTERVAL', 30),
        privateKeyPath =
            privateKeyPath ?? Platform.environment['IRCD_PRIVATE_KEY'];

  static InternetAddress _defaultAddress() {
    final address = Platform.environment['IRCD_HOSTADDR'];
    if (address != null) {
      return InternetAddress(address);
    } else {
      return InternetAddress.anyIPv6;
    }
  }

  static int _defaultNumber(String key, int fallback) {
    final portStr = Platform.environment[key];
    if (portStr != null) {
      return int.tryParse(portStr, radix: 10) ?? fallback;
    } else {
      return fallback;
    }
  }
}
