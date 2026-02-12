import 'dart:io';

Future<String> readFileAsString(String path) {
  return File(path).readAsString();
}
