// Audio parameters v1, ported from HE-Music desktop/internal/audiodecrypt.
// AGPL-3.0; provenance and synchronization notes: README.md.
import 'dart:convert';
import 'dart:typed_data';

class AudioTransformParameters {
  AudioTransformParameters._(
    this.kind,
    this.key,
    this.box,
    this.hash,
    this.period,
    this.bias,
    this.first,
    this.segment,
    this.userAgent,
  );

  final int kind;
  final Uint8List key;
  final Uint8List box;
  final int hash, period, bias, first, segment;
  final String? userAgent;

  factory AudioTransformParameters.parse(String encoded) {
    try {
      if (encoded.isEmpty || encoded.length > 16384) {
        throw const FormatException();
      }
      // Go RawURLEncoding ignores CR/LF, while forbidding padding and nonzero tail bits.
      final transport = encoded.replaceAll('\r', '').replaceAll('\n', '');
      if (transport.isEmpty ||
          !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(transport)) {
        throw const FormatException();
      }
      final raw = base64Url.decode(base64Url.normalize(transport));
      if (base64Url.encode(raw).replaceAll('=', '') != transport) {
        throw const FormatException();
      }
      final text = utf8.decode(raw);
      _checkJson(text);
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic>) throw const FormatException();
      int number(String name) {
        final n = value[name];
        if (n == null) return 0;
        if (n is! int) throw const FormatException();
        return n;
      }

      Uint8List bytes(String name) {
        final b = value[name];
        if (b == null) return Uint8List(0);
        if (b is! String) throw const FormatException();
        // Go json/v2 byte strings use padded standard Base64, without CR/LF.
        if (!RegExp(
          r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
        ).hasMatch(b)) {
          throw const FormatException();
        }
        // Go json/v2 tolerates unused tail bits in the inner byte encoding.
        const alphabet =
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        var normalized = b;
        if (b.endsWith('==')) {
          final at = b.length - 3;
          normalized =
              '${b.substring(0, at)}${alphabet[alphabet.indexOf(b[at]) & 0x30]}==';
        } else if (b.endsWith('=')) {
          final at = b.length - 2;
          normalized =
              '${b.substring(0, at)}${alphabet[alphabet.indexOf(b[at]) & 0x3c]}=';
        }
        return base64.decode(normalized);
      }

      final kind = number('kind');
      final key = bytes('key'), box = bytes('box');
      final hash = number('hash'), period = number('period');
      final bias = number('bias'), first = number('first');
      final segment = number('segment');
      final ua = value['user_agent'];
      if (ua != null && ua is! String) throw const FormatException();
      final userAgent = ua as String?;
      final unsegmented =
          box.isEmpty && hash == 0 && first == 0 && segment == 0;
      final valid = switch (kind) {
        1 => unsegmented && period == 0 && bias == 0,
        2 =>
          unsegmented &&
              period >= 1 &&
              period <= 1 << 20 &&
              bias >= 0 &&
              bias <= 1 << 20,
        3 =>
          key.length == box.length &&
              hash != 0 &&
              segment >= 1 &&
              segment <= 1 << 20 &&
              first >= 0 &&
              first <= segment &&
              period == 0 &&
              bias == 0 &&
              !key.contains(0),
        4 =>
          unsegmented &&
              period == 0 &&
              bias == 0 &&
              [16, 24, 32].contains(key.length),
        _ => false,
      };
      if (number('v') != 1 ||
          key.isEmpty ||
          key.length > 4096 ||
          hash < 0 ||
          hash > 0xffffffff ||
          !valid ||
          (userAgent != null &&
              (utf8.encode(userAgent).length > 256 ||
                  userAgent.contains(RegExp(r'[\r\n\x00]'))))) {
        throw const FormatException();
      }
      return AudioTransformParameters._(
        kind,
        key.asUnmodifiableView(),
        box.asUnmodifiableView(),
        hash,
        period,
        bias,
        first,
        segment,
        userAgent,
      );
    } catch (_) {
      throw const FormatException('Invalid audio parameters');
    }
  }
}

// jsonDecode accepts duplicate members and unpaired surrogates; Go json/v2
// rejects both. Check these before decoding, including unknown JSON members.
void _checkJson(String text) {
  var pos = 0;
  void space() {
    while (pos < text.length && ' \t\r\n'.contains(text[pos])) {
      pos++;
    }
  }

  String string() {
    final start = pos++;
    while (pos < text.length) {
      final c = text[pos++];
      if (c == '\\') {
        pos++;
      } else if (c == '"') {
        final decoded = jsonDecode(text.substring(start, pos)) as String;
        for (var i = 0; i < decoded.length; i++) {
          final unit = decoded.codeUnitAt(i);
          if (unit >= 0xd800 && unit <= 0xdbff) {
            if (++i >= decoded.length ||
                decoded.codeUnitAt(i) < 0xdc00 ||
                decoded.codeUnitAt(i) > 0xdfff) {
              throw const FormatException();
            }
          } else if (unit >= 0xdc00 && unit <= 0xdfff) {
            throw const FormatException();
          }
        }
        return decoded;
      }
    }
    throw const FormatException();
  }

  void value(int depth) {
    if (depth > 10000) throw const FormatException();
    space();
    if (pos >= text.length) throw const FormatException();
    final c = text[pos];
    if (c == '"') {
      string();
      return;
    }
    if (c == '{' || c == '[') {
      pos++;
      space();
      final end = c == '{' ? '}' : ']';
      final keys = <String>{};
      if (pos < text.length && text[pos] == end) {
        pos++;
        return;
      }
      while (true) {
        space();
        if (c == '{') {
          if (pos >= text.length || text[pos] != '"') {
            throw const FormatException();
          }
          final name = string();
          if (!keys.add(name)) throw const FormatException();
          space();
          if (pos >= text.length || text[pos++] != ':') {
            throw const FormatException();
          }
          space();
          // Even -0 cannot be unmarshaled into Go's uint32 hash field.
          if (depth == 0 &&
              name == 'hash' &&
              pos < text.length &&
              text[pos] == '-') {
            throw const FormatException();
          }
        }
        value(depth + 1);
        space();
        if (pos >= text.length) throw const FormatException();
        final next = text[pos++];
        if (next == end) return;
        if (next != ',') throw const FormatException();
      }
    }
    final start = pos;
    while (pos < text.length && !',]} \t\r\n'.contains(text[pos])) {
      pos++;
    }
    if (start == pos) throw const FormatException();
  }

  value(0);
  space();
  if (pos != text.length) throw const FormatException();
}
