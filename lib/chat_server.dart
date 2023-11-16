/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'package:dircd/channel.dart';
import 'package:dircd/client.dart';
import 'package:dircd/connection_auth.dart';

abstract interface class ChatServer implements ConnectionAuth {
  String get servername;

  Future<void> broadcast(
    List<int> data, {
    required Client from,
    required String to,
  });

  Future<void> unicast(
    List<int> data, {
    required Client from,
    required String to,
  });

  bool registerClientWithNick(String nick, Client client);
  bool changeClientNick({
    required Client client,
    required String from,
    required String to,
  });
  bool isOn(String nick);

  Future<void> join(
    List<int> data, {
    required String channel,
    required String? key,
    required Client user,
  });

  Future<void> part(
    List<int> data, {
    required Channel channel,
    required Client user,
  });

  Future<void> sendMotd({required Client to});
}
