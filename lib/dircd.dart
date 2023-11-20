/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dircd/channel.dart';
import 'package:dircd/chat_server.dart';
import 'package:dircd/client.dart';
import 'package:dircd/connection_auth.dart';
import 'package:dircd/numeric_reply.dart';

class Server implements ChatServer {
  final _unregistered = <Client>[];
  final _clients = <String, Client>{};
  final _channels = <String, Channel>{};
  final encoding = const Utf8Codec(allowMalformed: true);
  final ConnectionAuth connectionAuth;

  final String? _motdPath;

  Server({
    String? connectionPassword,
    ConnectionAuth? connectionAuth,
    String? motdPath,
  })  : connectionAuth = connectionAuth ??
            _fixedServerPassword(connectionPassword) ??
            ConnectionAuth(),
        _motdPath = motdPath ?? Platform.environment['IRCD_MOTD'];

  static ConnectionAuth? _fixedServerPassword(String? connectionPassword) {
    final password =
        connectionPassword ?? Platform.environment['IRCD_PASSWORD'];
    return password != null
        ? FixedStringConnectionAuth(password: password)
        : null;
  }

  @override
  authenticate({required nick, required user, password}) =>
      connectionAuth.authenticate(nick: nick, user: user, password: password);

  /// Start a server.
  ///
  /// [address] default is 0.0.0.0
  ///
  /// [port] default is 6667
  ///
  /// If [privateKeyPath] is not null, server listen with TLS enabled.
  /// It's file contents must contains both CERTIFICATE and PRIVATE KEY.
  /// So it's just looks like:
  ///
  ///     -----BEGIN CERTIFICATE-----
  ///     abcabc...
  ///     -----END CERTIFICATE-----
  ///     -----BEGIN PRIVATE KEY-----
  ///     xyzxyz...
  ///     -----END PRIVATE KEY-----
  Future<void> run({
    InternetAddress? address,
    int? port,
    int connectionCheckIntervalSeconds = 30,
    String? privateKeyPath,
    String? motdPath,
  }) async {
    final addr = address ??
        InternetAddress(Platform.environment['IRCD_HOSTADDR'] ?? '0.0.0.0');
    final portStr = Platform.environment['IRCD_PORT'];
    final portNum = port ??
        (portStr != null ? int.tryParse(portStr, radix: 10) : null) ??
        6667;
    final certKeyPath =
        privateKeyPath ?? Platform.environment['IRCD_PRIVATE_KEY'];

    final ponger = Timer.periodic(
      Duration(seconds: connectionCheckIntervalSeconds),
      (_) => _checkClientConnection(DateTime.now()),
    );

    if (certKeyPath == null) {
      final server = await ServerSocket.bind(addr, portNum);
      _listen(server, ponger);

      print(banner);
      print('Listen on: ${server.address.address}:${server.port}');
    } else {
      final securityContext = SecurityContext()
        ..useCertificateChain(certKeyPath)
        ..usePrivateKey(certKeyPath);
      final server = await SecureServerSocket.bind(
        addr,
        portNum,
        securityContext,
      );
      _listen(server, ponger);

      print(banner);
      print('Listen on: ${server.address.address}:${server.port} with TLS');
    }
  }

  void _listen<T extends Stream<S>, S extends Socket>(
    T serverSocket,
    Timer ponger,
  ) {
    serverSocket.listen(
      (socket) {
        final client = Client(
          socket: socket,
          encoding: encoding,
          chatServer: this,
        );
        _unregistered.add(client);
        client.accept(
          onDone: () {
            if (client.registered) {
              _clients.remove(client.nick);
            } else {
              _unregistered.remove(client);
            }
          },
          onError: (error, stackTrace) {
            if (client.registered) {
              _clients.remove(client.nick);
            } else {
              _unregistered.remove(client);
            }
            print(stackTrace);
          },
        );
      },
      onError: (error, stackTrace) {
        ponger.cancel();
        print(error);
        print(stackTrace);
      },
      onDone: () {
        ponger.cancel();
        print('done');
      },
    );
  }

  String get banner => '\r\n'
      '    +-+-+-+-+-+\r\n'
      '    |d|i|r|c|d|\r\n'
      '    +-+-+-+-+-+\r\n';

  @override
  get servername => 'irc.example.net';

  void _checkClientConnection(DateTime time) {
    print('Clients: ${_clients.length} (${_unregistered.length} unregistered),'
        ' Channels: ${_channels.length}');
    Future.wait(_clients.values.map((cl) => cl.checkConnectionActivity(time)));
    Future.wait(_unregistered.map((cl) => cl.checkConnectionActivity(time)));
  }

  bool _isNickInUse(String nick) {
    if (_clients.containsKey(nick)) return true;
    if (nick == 'anonymous') return true;
    if (nick.endsWith('serv')) return true;
    return false;
  }

  @override
  registerClientWithNick(nick, client) {
    if (_isNickInUse(nick)) return false;

    _unregistered.remove(client);
    _clients[nick] = client;

    return true;
  }

  @override
  changeClientNick({required client, required from, required to}) {
    if (_isNickInUse(to)) return false;

    _clients.remove(from);
    _clients[to] = client;
    return true;
  }

  @override
  isOn(nick) => _clients.containsKey(nick);

  @override
  broadcast(data, {required from, required to}) async {
    final chan = _channels[to];
    if (chan == null) {
      from.sendNumericWith(NumericReply.ERR_NOSUCHCHANNEL, [to]);
      return;
    }

    if (chan.isFlagOn('n') && !chan.isOnChannel(client: from)) {
      from.sendNumericWith(NumericReply.ERR_NOTONCHANNEL, [to]);
      return;
    }

    chan.broadcast(data, from: from, echo: false);
  }

  @override
  unicast(data, {required from, required to}) async {
    final client = _clients[to];
    if (client == null) {
      from.sendNumericWith(NumericReply.ERR_NOSUCHNICK, [to]);
      return;
    }

    client.sendRawData(data);
  }

  @override
  join(data, {required channel, required key, required user}) async {
    var chan = _channels[channel];
    if (chan != null) {
      if (!chan.add(user, key: key)) {
        user.sendNumericWith(NumericReply.ERR_BADCHANNELKEY, [channel]);
        return;
      }
    } else {
      // Create new channel.
      chan = Channel(name: channel, key: key)..add(user, key: key);
      chan.setFlag('n', on: true);
      _channels[channel] = chan;
    }

    user.add(chan);
    chan.broadcast(data, from: user);

    chan.sendChannelInfo(to: user);
  }

  @override
  part(data, {required channel, required user}) async {
    channel.remove(user);
    if (channel.isEmpty) {
      _channels.remove(channel.name);
    } else {
      channel.broadcast(data, from: user);
    }
    user.sendRawData(data);
  }

  @override
  sendMotd({required to}) async {
    if (_motdPath == null) {
      // Fallback to default contents.

      to.sendMotdStart();

      final prefix = to.printNumeric(NumericReply.RPL_MOTD);
      to.sendRawString('$prefix :- This is dircd, Internet Relay Chat daemon.');
      to.sendRawString('$prefix :-');
      for (final line in _license()) {
        to.sendRawString('$prefix :- $line');
      }

      to.sendEndOfMotd();
      return;
    }

    try {
      final file = File(_motdPath);
      final lines = file
          .openRead()
          .transform(const Utf8Decoder())
          .transform(const LineSplitter());
      final prefix = to.printNumeric(NumericReply.RPL_MOTD);

      to.sendMotdStart();

      await for (final line in lines) {
        to.sendRawString('$prefix :- $line\r\n');
      }

      to.sendEndOfMotd();
    } on PathNotFoundException {
      to.sendNumeric(NumericReply.ERR_NOMOTD);
    }
  }

  List<String> _license() => [
        'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR',
        'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,',
        'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE',
        'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER',
        'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING',
        'FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER',
        'DEALINGS IN THE SOFTWARE.',
      ];
}
