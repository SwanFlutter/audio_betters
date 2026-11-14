// Platform-agnostic file helpers for the example app.
//
// The example must compile on every platform the plugin supports, including
// Web — where `dart:io` is unavailable at compile time. This barrel selects a
// `dart:io`-based implementation on native platforms and a browser-safe stub
// on Web via a conditional export.
export 'paths_io.dart' if (dart.library.js) 'paths_web.dart';
