/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:convert';

extension JoinWithPrefix on Iterable<String> {
  List<String> joinWithPrefix(
    String prefix, {
    required int maxLength,
    Encoding encoding = const Utf8Codec(),
  }) {
    final plen = encoding.encode(prefix).length;
    final ulen = maxLength - plen;

    final a = <String>[];
    var sb = StringBuffer(prefix);
    var next = false;
    var len = 0;
    for (final item in this) {
      len += item.length + (next ? 1 : 0);
      if (ulen < len) {
        a.add(sb.toString());
        sb = StringBuffer(prefix);
        len = item.length;
        next = false;
      }
      if (next) {
        sb.write(' ');
      } else {
        next = true;
      }
      sb.write(item);
    }
    if (0 < len) {
      a.add(sb.toString());
    }
    return a;
  }
}
