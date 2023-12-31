/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:collection';

import 'package:dircd/client.dart';
import 'package:dircd/numeric_reply.dart';
import 'package:dircd/string_ext.dart';

class Channel {
  final String name;

  final _clients = HashSet<Client>.of([]);
  final _flags = HashSet<String>.of([]);

  String? _topic;
  String? key;

  Channel({required this.name, this.key});

  bool get isEmpty => _clients.isEmpty;
  List<Client> get clients => _clients.toList(growable: false);

  String? get topic => _topic;
  set topic(String? newTopic) {
    if (newTopic == null || newTopic.isEmpty) {
      _topic = null;
    } else {
      _topic = newTopic;
    }
  }

  bool isOnChannel({required Client client}) => _clients.contains(client);

  String get flags => '+${_flags.join()}';

  bool isFlagOn(String ch) => _flags.contains(ch);

  bool setFlag(String ch, {required bool on}) {
    // Return true when changed.
    if (on) {
      return _flags.add(ch);
    } else {
      return _flags.remove(ch);
    }
  }

  bool add(Client user, {String? key}) {
    if (this.key != null && this.key != key) return false;
    _clients.add(user);
    return true;
  }

  void remove(Client user) {
    _clients.remove(user);
  }

  void broadcast(List<int> data, {required Client from, bool echo = true}) {
    for (final cl in _clients) {
      if (!echo && cl == from) continue;
      cl.sendRawData(data);
    }
  }

  void sendChannelInfo({required Client to}) {
    if (_clients.length > 1) {
      if (_topic != null) {
        to.sendNumericWith(NumericReply.RPL_TOPIC, [name], text: _topic);
      } else {
        to.sendNumericWith(NumericReply.RPL_NOTOPIC, [name]);
      }
    }
    final basePrefix = to.printNumeric(NumericReply.RPL_NAMREPLY);
    final prefix = '$basePrefix = $name :';
    for (final namlist in members.joinWithPrefix(prefix, maxLength: 510)) {
      to.sendRawString(namlist);
    }
    to.sendNumericWith(NumericReply.RPL_ENDOFNAMES, [name]);
  }

  Iterable<String> get members => _clients.map((cl) => cl.nick);
}
