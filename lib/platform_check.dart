import 'dart:io' show Platform;

bool isDesktop() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
