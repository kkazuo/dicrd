/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:convert';

import 'package:dircd/numeric_reply.dart';

class Message {
  final String? prefix;
  final String command;
  final List<String> params;

  Message({this.prefix, required this.command, required this.params});

  factory Message.parse(List<String> rowMessage) {
    if (rowMessage.isEmpty) throw ArgumentError.value(rowMessage);
    return Message(command: rowMessage.first, params: rowMessage.sublist(1));
  }

  @override
  String toString() {
    final p = prefix == null ? '' : '($prefix) ';
    return '$p$command $params';
  }

  static String printNumeric(NumericReply n) => _intToString(n.code);

  static String _intToString(int n) {
    if (100 <= n) return n.toString();
    if (10 <= n) return '0$n';
    if (0 <= n) return '00$n';
    return n.toString();
  }

  static List<int> encodeNumeric(
    String from,
    String to,
    NumericReply n,
    Encoding encoding,
  ) {
    final code = _intToString(n.code);
    return encoding.encode(':$from $code $to :${n.desc}\r\n');
  }

  static List<int> encodeNumericWith(
    String from,
    String to,
    NumericReply n,
    List<String> params,
    Encoding encoding, {
    String? text,
  }) {
    final code = _intToString(n.code);
    final ps = params.join(' ');
    final last = text ?? n.desc;
    return encoding.encode(':$from $code $to $ps :$last\r\n');
  }

  static final _nickRe = RegExp(
    r'^[A-Za-z`_^[\\\]{|}][-A-Za-z0-9`_^[\\\]{|}]{0,15}$',
    unicode: true,
  );
  static bool isValidAsNickname(String input) => _nickRe.hasMatch(input);

  static bool isValidAsUserName(String input) => !input.contains('@');

  static bool isValidAsChannelName(String input) =>
      input.isNotEmpty && input[0] == '#' && isValidAsChanstring(input);

  static bool isValidAsChanstring(String input, {int start = 1}) =>
      !input.contains('\x07,:', start);
}
