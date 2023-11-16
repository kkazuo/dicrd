/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import 'dart:convert';
import 'dart:typed_data';

class _ConversionSink implements ChunkedConversionSink<Uint8List> {
  final Sink<Uint8List> sink;

  BytesBuilder _builder;
  int _chLast;

  _ConversionSink({required this.sink})
      : _builder = BytesBuilder(copy: false),
        _chLast = 0;

  @override
  void add(chunk) {
    var start = 0;
    do {
      final end = chunk.indexWhere(
        (element) => element == 10 || element == 13 || element == 0,
        start,
      );
      if (end == -1) {
        _accumlate(chunk, start, chunk.length);
        return;
      }
      final ch = chunk[end];
      if (ch == 13) {
        if (_chLast == 13) {
          //
        } else {
          _accumlate(chunk, start, end);
        }
      } else if (ch == 10) {
        if (_chLast == 13) {
          _flush();
        } else {
          _accumlate(chunk, start, end);
        }
      } else if (ch == 0) {
        _accumlate(chunk, start, end);
      }
      _chLast = ch;
      start = end + 1;
      continue;
    } while (true);
  }

  void _accumlate(Uint8List chunk, int start, int end) {
    if (start < end) {
      if (510 < _builder.length) return;
      _builder.add(Uint8List.sublistView(chunk, start, end));
    }
  }

  void _flush() {
    if (_builder.isNotEmpty) {
      final data = _builder.toBytes();
      _builder = BytesBuilder(copy: false);
      sink.add(data);
    }
  }

  @override
  void close() {
    _flush();
    sink.close();
  }
}

/// Split stream into IRC message chunk
class BytesSplitter extends Converter<Uint8List, Uint8List> {
  @override
  convert(input) => throw UnimplementedError();

  @override
  startChunkedConversion(sink) => _ConversionSink(sink: sink);
}
