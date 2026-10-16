import 'dart:convert';
import 'dart:js_interop';

const available = true;

@JS('localStorage')
external _LocalStorage get _storage;

extension type _LocalStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

Map<String, dynamic> read(String key) {
  final raw = _storage.getItem('treasure/audio/$key'.toJS)?.toDart;
  if (raw == null) return {};
  return Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

void write(String key, Map<String, dynamic> data) =>
    _storage.setItem('treasure/audio/$key'.toJS, jsonEncode(data).toJS);
