/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:cuid2/cuid2.dart';
import 'package:dircd/bytes_decoder.dart';
import 'package:dircd/bytes_splitter.dart';
import 'package:dircd/channel.dart';
import 'package:dircd/chat_server.dart';
import 'package:dircd/frame_decoder.dart';
import 'package:dircd/message.dart';
import 'package:dircd/numeric_reply.dart';
import 'package:dircd/user_info.dart';

/// The chat client that connects to this server.
class Client {
  final ChatServer _chatServer;
  final Socket _socket;
  final String cloakHost;
  final InternetAddress remoteAddress;
  final int remotePort;
  final Encoding _encoding;
  final _channels = <String, Channel>{};

  bool _registered = false;
  bool _authenticating = false;
  bool _capNegotiating = false;
  String? _connectPassword;
  String? _nick;
  UserInfo? _user;
  DateTime _lastResponseTime;
  DateTime _lastNickChange;

  Client({
    required ChatServer chatServer,
    required Socket socket,
    required Encoding encoding,
  })  : _chatServer = chatServer,
        _socket = socket,
        cloakHost = cuidConfig(
          length: 18,
          fingerprint: () => '${socket.remoteAddress}:${socket.remotePort}',
        ).gen(),
        remoteAddress = socket.remoteAddress,
        remotePort = socket.remotePort,
        _encoding = encoding,
        _lastResponseTime = DateTime.now(),
        _lastNickChange = DateTime.now();

  @override
  String toString() {
    return '$cloakHost ($remoteAddress $remotePort)';
  }

  bool get registered => _registered;

  String get nick => _registered ? _nick! : '*';

  String get _fqun => '${_nick ?? '*'}'
      '!${_user?.user ?? '*'}'
      '@$cloakHost.u.${_chatServer.servername}';

  List<Client> _knownClients() {
    final clients = _channels.values
        .map((channel) => channel.clients)
        .fold(
          HashSet<Client>(),
          (previousValue, element) => previousValue..addAll(element),
        )
        .toList(growable: false);
    if (clients.isEmpty) {
      return [this];
    }
    return clients;
  }

  void add(Channel channel) {
    _channels[channel.name] = channel;
  }

  void remove(Channel channel) {
    _channels.remove(channel.name);
  }

  StreamSubscription<Message> accept({
    required void Function() onDone,
    required void Function(dynamic error, dynamic stackTrace) onError,
  }) {
    return _socket
        .transform(BytesSplitter())
        .transform(BytesDecoder())
        .transform(FrameDecoder())
        .listen(
      (event) {
        _lastResponseTime = DateTime.now();
        switch (event.command.toUpperCase()) {
          case 'PRIVMSG':
            _onPrivmsg(event);
            return;
          case 'NOTICE':
            _onNotice(event);
            return;
          case 'PASS':
            return _onPass(event);
          case 'NICK':
            return _onNick(event);
          case 'USER':
            return _onUser(event);
          case 'QUIT':
            _onQuit(event);
            return;
          case 'PING':
            return _onPing(event);
          case 'PONG':
            return _onPong(event);
          case 'JOIN':
            return _onJoin(event);
          case 'PART':
            return _onPart(event);
          case 'MODE':
            return _onMode(event);
          case 'TOPIC':
            return _onTopic(event);
          case 'ISON':
            return _onIson(event);
          case 'MOTD':
            return _onMotd(event);
          case 'CAP':
            return _onCap(event);
          case 'ERROR':
            return _onError(event);
          default:
            print(event);
            return _onUnknown(event);
        }
      },
      onError: (error, stackTrace) {
        print(error);
        _closeSocket(flush: false)
            .then((_) => onError(error, stackTrace))
            .catchError(onError);
      },
      onDone: () {
        _closeSocket().then((_) => onDone()).catchError(onError);
      },
      cancelOnError: true,
    );
  }

  void _onError(Message event) {
    // Ignore silently.
  }

  void _onUnknown(Message event) {
    if (!_registered) return;

    sendNumericWith(NumericReply.ERR_UNKNOWNCOMMAND, [event.command]);
  }

  void _onPass(Message event) {
    if (_registered) {
      sendNumeric(NumericReply.ERR_ALREADYREGISTRED);
    } else if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NEEDMOREPARAMS);
    } else {
      _connectPassword = event.params.first;
    }
  }

  void _onNick(Message event) {
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NONICKNAMEGIVEN);
      return;
    }

    final input = event.params.first;
    if (!Message.isValidAsNickname(input)) {
      sendNumericWith(NumericReply.ERR_ERRONEUSNICKNAME, [input]);
      return;
    }

    final newNick = input.toLowerCase();

    if (!_registered) {
      _nick = newNick;
      _tryRegistration();
      return;
    }

    // For nick change abuse protection.
    {
      final now = DateTime.now();
      final elapsed = now.difference(_lastNickChange);
      if (elapsed < const Duration(seconds: 60)) {
        _lastNickChange = now;
        sendNumericWith(NumericReply.ERR_NICKNAMEINUSE, [input]);
        return;
      }
    }

    if (!_chatServer.changeClientNick(
      client: this,
      from: _nick!,
      to: newNick,
    )) {
      sendNumericWith(NumericReply.ERR_NICKNAMEINUSE, [input]);
      return;
    }
    _lastNickChange = DateTime.now();

    final data = _encoding.encode(':$_fqun NICK $newNick\r\n');
    _nick = newNick;

    for (final client in _knownClients()) {
      client.sendRawData(data);
    }
  }

  void _onUser(Message event) {
    if (_registered) {
      sendNumeric(NumericReply.ERR_ALREADYREGISTRED);
      return;
    }
    if (event.params.length < 4) {
      sendNumeric(NumericReply.ERR_NEEDMOREPARAMS);
      return;
    }

    final user = event.params[0];
    final mode = event.params[1];
    final realname = event.params[3];

    if (!Message.isValidAsUserName(user)) {
      sendNumeric(NumericReply.ERR_ALREADYREGISTRED);
      return;
    }

    _user = UserInfo(user: user, mode: mode, realname: realname);
    _tryRegistration();
  }

  Future<void> _closeSocket({bool flush = true}) async {
    if (flush) await _socket.flush();
    await _socket.close();
  }

  void _onPing(Message event) {
    // Ignore silently.
  }

  Future<void> _tryRegistration() async {
    final nick = _nick;
    final user = _user?.user;
    if (nick == null || user == null) return;

    if (_capNegotiating) return;
    if (_authenticating) return;
    _authenticating = true;
    final (success, reason) = await _chatServer.authenticate(
      nick: nick,
      user: user,
      password: _connectPassword,
    );
    _connectPassword = null;

    if (!success) {
      final details = reason != null ? ' :$reason' : '';
      final data = _encoding.encode('ERROR :Authentication Failed:'
          ' nick=$nick user=$user'
          '$details\r\n');
      sendRawData(data);
      await _onQuit(null);
      return;
    }

    final registered = _chatServer.registerClientWithNick(nick, this);
    _authenticating = false;

    if (!registered) {
      // the Nick is in use.
      sendNumericWith(NumericReply.ERR_NICKNAMEINUSE, [nick]);
      return;
    }

    _registered = true;
    _welcome();
    _chatServer.sendMotd(to: this);
  }

  void _welcome() {
    final to = nick;
    final servername = _chatServer.servername;
    const daemonVersion = 'dircd.1.0.0';
    const date = 'Thu Jan 1 1970 at 00:00:00 UTC';
    const userMode = 'o';
    const chanMode = 'sn';
    final isupports = [
      'UTF8ONLY',
      'CASEMAPPING=ascii',
      'NICKLEN=16',
      'CHANTYPES=#',
    ].join(' ');
    final m =
        ':$servername 001 $to :Welcome to the Internet Relay Network $_fqun\r\n'
        ':$servername 002 $to :Your host is $servername, running version $daemonVersion\r\n'
        ':$servername 003 $to :This server was created $date\r\n'
        ':$servername 004 $to $servername $daemonVersion $userMode $chanMode\r\n'
        ':$servername 005 $to $isupports :are supported by this server\r\n';
    sendRawData(_encoding.encode(m));
  }

  void sendRawData(List<int> data) {
    _socket.add(data);
  }

  void sendRawString(String text) {
    sendRawData(_encoding.encode(text) + [13, 10]);
  }

  String printNumeric(NumericReply n) {
    final to = nick;
    return ':${_chatServer.servername} ${Message.printNumeric(n)} $to';
  }

  void sendNumeric(NumericReply n) {
    final servername = _chatServer.servername;
    final to = nick;
    final data = Message.encodeNumeric(servername, to, n, _encoding);
    sendRawData(data);
  }

  void sendNumericWith(
    NumericReply n,
    List<String> params, {
    String? text,
  }) {
    final servername = _chatServer.servername;
    final to = nick;
    final data = Message.encodeNumericWith(
      servername,
      to,
      n,
      params,
      _encoding,
      text: text,
    );
    sendRawData(data);
  }

  Future<void> checkConnectionActivity(DateTime time) async {
    final duration = time.difference(_lastResponseTime);
    if (duration < const Duration(seconds: 45)) return;
    if (!_registered || const Duration(seconds: 90) < duration) {
      await _onQuit(null);
      return;
    }
    _sendPing();
  }

  void _sendPing() {
    final host = _chatServer.servername;
    final data = _encoding.encode('PING $host\r\n');
    sendRawData(data);
  }

  void _onPong(Message event) {
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NOORIGIN);
    }
  }

  void _onJoin(Message event) {
    if (!_registered) return;
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NEEDMOREPARAMS);
      return;
    }

    final target = event.params[0];
    final keys = event.params.length < 2 ? '' : event.params[1];

    if (target.contains(',') || keys.contains(',')) {
      sendNumericWith(NumericReply.ERR_TOOMANYTARGETS, [target]);
      return;
    }

    if (event.params.length == 1 && target == '0') {
      // as PART from ALL channel.
      // TODO
      sendNumericWith(NumericReply.ERR_NOSUCHCHANNEL, ['0']);
      return;
    }

    final channel = target.toLowerCase();
    final chankey = keys;

    if (!Message.isValidAsChannelName(channel)) {
      sendNumericWith(NumericReply.ERR_NOSUCHCHANNEL, [channel]);
      return;
    }

    if (_channels.containsKey(channel)) return;

    final fqun = _fqun;
    final data = _encoding.encode(':$fqun JOIN $channel\r\n');
    _chatServer.join(
      data,
      user: this,
      channel: channel,
      key: chankey.isNotEmpty ? chankey : null,
    );
  }

  Future<void> _onQuit(Message? event) async {
    if (_registered) {
      // Broadcast user quit.
      for (final chan in _channels.values) {
        chan.remove(this);
      }

      final quitmsg = event == null
          ? ' :Ping Timeout'
          : event.params.isNotEmpty
              ? ' :${event.params.first}'
              : '';
      final fqun = _fqun;
      for (final chan in _channels.values) {
        final data = _encoding.encode(':$fqun QUIT$quitmsg\r\n');
        chan.broadcast(data, from: this, echo: false);
      }
    }
    await _closeSocket();
  }

  void _onPart(Message event) {
    if (!_registered) return;
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NEEDMOREPARAMS);
      return;
    }

    final target = event.params[0];
    final partMessage = event.params.length < 2 ? null : event.params[1];

    if (target.contains(',')) {
      sendNumericWith(NumericReply.ERR_TOOMANYTARGETS, [target]);
      return;
    }

    final channel = target.toLowerCase();

    if (!Message.isValidAsChannelName(channel)) {
      sendNumericWith(NumericReply.ERR_NOSUCHCHANNEL, [channel]);
      return;
    }

    final chan = _channels.remove(channel);
    if (chan == null) {
      sendNumericWith(NumericReply.ERR_NOTONCHANNEL, [channel]);
      return;
    }

    final partmsg = partMessage != null ? ' :$partMessage' : '';
    final fqun = _fqun;
    final data = _encoding.encode(':$fqun PART $channel$partmsg\r\n');
    _chatServer.part(data, user: this, channel: chan);
  }

  void _onIson(Message event) {
    if (!_registered) return;
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NEEDMOREPARAMS);
      return;
    }

    final ison = <String>[];
    for (final nk in event.params) {
      if (!Message.isValidAsNickname(nk)) continue;
      final nklow = nk.toLowerCase();
      if (ison.indexWhere((element) => element.toLowerCase() == nklow) != -1) {
        continue;
      }
      if (_chatServer.isOn(nklow)) {
        ison.add(nk);
      }
    }

    final reply = ison.join(' ');
    final numeric = printNumeric(NumericReply.RPS_ISON);
    final data = _encoding.encode('$numeric :$reply\r\n');
    sendRawData(data);
  }

  void _onPrivmsg(Message event) {
    if (!_registered) return;
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NORECIPIENT);
      return;
    }
    if (event.params.length < 2) {
      sendNumeric(NumericReply.ERR_NOTEXTTOSEND);
      return;
    }

    final target = event.params[0];
    final text = event.params[1];

    if (target.contains(',')) {
      sendNumericWith(NumericReply.ERR_TOOMANYTARGETS, [target]);
      return;
    }

    final fqun = _fqun;
    final command = event.command.toUpperCase();
    final msgto = target.toLowerCase();
    data() => _encoding.encode(':$fqun $command $msgto :$text\r\n');

    if (Message.isValidAsChannelName(msgto)) {
      // Send to the channel
      final channel = _channels[msgto];
      if (channel == null) {
        sendNumericWith(NumericReply.ERR_NOTONCHANNEL, [msgto]);
        return;
      }

      _chatServer.broadcast(data(), from: this, to: msgto);
      return;
    }

    if (Message.isValidAsNickname(msgto)) {
      // Send to the user by nick
      _chatServer.unicast(data(), from: this, to: msgto);
      return;
    }

    sendNumericWith(NumericReply.ERR_NOSUCHNICK, [msgto]);
  }

  void _onNotice(Message event) {
    return _onPrivmsg(event);
  }

  void _onMotd(Message event) {
    if (!_registered) return;

    _chatServer.sendMotd(to: this);
  }

  void sendMotdStart() {
    final prefix = printNumeric(NumericReply.RPL_MOTDSTART);
    final servername = _chatServer.servername;
    sendRawString('$prefix :- $servername Message of the day -');
  }

  void sendEndOfMotd() {
    sendNumeric(NumericReply.RPL_ENDOFMOTD);
  }

  void _onMode(Message event) {
    if (!_registered) return;

    print(event);

    final channame = event.params.first;

    if (!Message.isValidAsChannelName(channame)) {
      sendNumericWith(NumericReply.ERR_NOSUCHCHANNEL, [channame]);
      return;
    }

    final channel = _channels[channame.toLowerCase()];

    if (channel == null) {
      sendNumericWith(NumericReply.ERR_NOTONCHANNEL, [channame]);
      return;
    }

    sendNumericWith(NumericReply.RPL_CHANNELMODEIS, [channame, '+n']);
  }

  void _onTopic(Message event) {
    if (!_registered) return;
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_NEEDMOREPARAMS);
      return;
    }

    final channame = event.params.first;

    if (!Message.isValidAsChannelName(channame)) {
      sendNumericWith(NumericReply.ERR_NOSUCHCHANNEL, [channame]);
      return;
    }

    final channel = _channels[channame.toLowerCase()];

    if (channel == null) {
      sendNumericWith(NumericReply.ERR_NOTONCHANNEL, [channame]);
      return;
    }

    if (event.params.length == 1) {
      final topic = channel.topic;
      if (topic == null) {
        sendNumeric(NumericReply.RPL_NOTOPIC);
      } else {
        sendNumericWith(NumericReply.RPL_TOPIC, [channame], text: topic);
      }
      return;
    }

    final topic = event.params.last;
    channel.topic = topic;

    final data = _encoding.encode(':$_fqun TOPIC ${channel.name} :$topic\r\n');
    channel.broadcast(data, from: this);
  }

  void _onCap(Message event) {
    if (event.params.isEmpty) {
      sendNumeric(NumericReply.ERR_INVALIDCAPCMD);
      return;
    }

    final capSubCommand = event.params.first;
    switch (capSubCommand.toUpperCase()) {
      case 'LS':
        if (_registered) return;
        return _onCapList(event, 'LS');
      case 'LIST':
        if (_registered) return;
        return _onCapList(event, 'LIST');
      case 'REQ':
        if (_registered) return;
        return _onCapReq(event);
      case 'END':
        if (_registered) return;
        return _onCapEnd(event);
      default:
        sendNumericWith(NumericReply.ERR_INVALIDCAPCMD, [capSubCommand]);
        return;
    }
  }

  void _onCapList(Message event, String subCommand) {
    _capNegotiating = true;

    final data = _encoding.encode('CAP $nick $subCommand :\r\n');
    sendRawData(data);
  }

  void _onCapReq(Message event) {
    _capNegotiating = true;

    final caps = event.params.lastOrNull ?? '';
    final data = _encoding.encode('CAP $nick NAK :$caps\r\n');
    sendRawData(data);
  }

  void _onCapEnd(Message event) {
    _capNegotiating = false;
    _tryRegistration();
  }
}
