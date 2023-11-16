/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:convert';
import 'dart:typed_data';
import 'package:dircd/bytes_decoder.dart';
import 'package:dircd/bytes_splitter.dart';
import 'package:dircd/message.dart';
import 'package:dircd/string_ext.dart';
import 'package:test/test.dart';

void main() {
  Future<List<List<String>>> conv(BytesDecoder d, List<Uint8List> xs) async {
    return await Stream.fromIterable(xs).transform(d).toList();
  }

  Future<List<String>> split(BytesSplitter d, List<Uint8List> xs) async {
    return await Stream.fromIterable(xs)
        .transform(d)
        .map((event) => const Utf8Codec().decode(event))
        .toList();
  }

  test('string join (short)', () {
    const prefix = ':ABC 000 = #a :';
    final actual = ['1', '22'].joinWithPrefix(prefix, maxLength: 50);
    expect(actual, ['${prefix}1 22']);
    expect(<String>[].joinWithPrefix(prefix, maxLength: 50), []);
  });

  test('string join', () {
    const prefix = ':ABC 000 = #あ :';
    final src = [
      '1',
      '22',
      '333',
      '4444',
      '55555',
      '1',
      '22',
      '333',
      '4444',
      '55555',
      '1',
    ];
    final actual = src.joinWithPrefix(prefix, maxLength: 29);
    expect(actual, [
      '${prefix}1 22 333',
      '${prefix}4444 55555 1',
      '${prefix}22 333 4444',
      '${prefix}55555 1',
    ]);
  });

  test('nickname', () {
    expect(Message.isValidAsNickname('a'), true);
    expect(Message.isValidAsNickname('0_'), false);
    expect(Message.isValidAsNickname('-a'), false);
    expect(Message.isValidAsNickname('_a'), true);
    expect(Message.isValidAsNickname('`a`'), true);
    expect(Message.isValidAsNickname(r'\r'), true);
  });

  test('byte splitter', () async {
    const u = Utf8Encoder();
    final d = BytesSplitter();

    expect(
      await split(d, [
        u.convert('NICK nick\r\n'),
        u.convert('USER user\r\n'),
      ]),
      ['NICK nick', 'USER user'],
    );
    expect(
      await split(d, [
        u.convert('A\r'),
        u.convert('\nB'),
      ]),
      ['A', 'B'],
    );
    expect(
      await split(d, [
        u.convert('A\r\r\n'
            'B\x00\r\n'
            'C\n\r\n'
            'D\r1\x00\n\r\n'
            'E\n\r\n'),
      ]),
      ['A', 'B', 'C', 'D1', 'E'],
    );
  });

  test('byte decoder', () async {
    const u = Utf8Encoder();
    final d = BytesDecoder();

    expect(
        await conv(d, [
          u.convert('NICK nick'),
          u.convert('USER user'),
        ]),
        [
          ['NICK', 'nick'],
          ['USER', 'user'],
        ]);
    expect(
        await conv(d, [
          u.convert(':example.com NICK nick'),
          u.convert('USER user 0 * :Hello world'),
        ]),
        [
          [':example.com', 'NICK', 'nick'],
          ['USER', 'user', '0', '*', 'Hello world'],
        ]);
    expect(
        await conv(d, [
          u.convert('QUIT :'),
        ]),
        [
          ['QUIT', ''],
        ]);
    expect(
        await conv(d, [
          u.convert(' P'),
        ]),
        [
          ['', 'P'],
        ]);
    expect(
        await conv(d, [
          u.convert(' :p P'),
        ]),
        [
          ['', 'p P'],
        ]);
  });
}
