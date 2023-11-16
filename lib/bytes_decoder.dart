/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:convert';
import 'dart:typed_data';

class _ConversionSink implements ChunkedConversionSink<Uint8List> {
  final Sink<List<String>> sink;

  _ConversionSink({required this.sink});

  @override
  void add(chunk) {
    const codec = Utf8Codec(allowMalformed: true);
    final items = <String>[];

    var start = 0;
    do {
      final end = chunk.indexOf(32, start);
      if (end == -1) {
        if (start < chunk.length) {
          if (0 < start && chunk[start] == 58) {
            start += 1;
          }
          items.add(codec.decoder.convert(chunk, start, chunk.length));
        }
        break;
      }

      if (0 < start && chunk[start] == 58) {
        items.add(codec.decoder.convert(chunk, start + 1, chunk.length));
        break;
      }

      items.add(codec.decoder.convert(chunk, start, end));

      start = end + 1;
    } while (true);
    if (items.isNotEmpty) {
      sink.add(items);
    }
  }

  @override
  void close() {
    sink.close();
  }
}

/// Decode byte stream to IRC message
class BytesDecoder extends Converter<Uint8List, List<String>> {
  @override
  convert(input) => throw UnimplementedError();

  @override
  startChunkedConversion(sink) => _ConversionSink(sink: sink);
}
