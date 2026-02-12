import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission() async {
  final status = await Permission.storage.request();
  if (status.isGranted) return true;
  final manageStatus = await Permission.manageExternalStorage.request();
  return manageStatus.isGranted;
}
