import 'dart:io';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share/share.dart';
import 'package:twake/utils/constants.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:twake/config/styles_config.dart';

class Utilities {

  // Use this to get cached path from image that downloaded by cached_network_image
  // FYI: https://pub.dev/packages/cached_network_image#how-it-works
  static Future<String> getCachedImagePath(String imageUrl) async {
    var file = await DefaultCacheManager().getSingleFile(imageUrl);
    return file.path;
  }

  static void shareApp() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    var appUrl = 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';
    if(Platform.isIOS) {
      appUrl = 'https://itunes.apple.com/app/$IOS_APPSTORE_ID';
    }
    await Share.share(appUrl);
  }

  static void showSimpleSnackBar({required String message, String? iconPath}) {
    Get.snackbar('', '',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.white,
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(16.0),
        animationDuration: Duration(milliseconds: 300),
        duration: const Duration(milliseconds: 1500),
        icon: iconPath != null ? Image.asset(iconPath, width: 40, height: 40) : null,
        titleText: SizedBox.shrink(),
        messageText: Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Text(message,
              style: StylesConfig.commonTextStyle.copyWith(fontSize: 15)),

        ),
        boxShadows: [
          BoxShadow(
            blurRadius: 16,
            color: Color.fromRGBO(0, 0, 0, 0.24),
          )
        ]
    );
  }

  static Future<bool> _isNeedRequestStoragePermissionOnAndroid() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt <= 28;
  }

  static Future<bool> checkAndRequestPermission() async {
    if(Platform.isIOS) {
      return true;
    }
    final needRequestPermission = await _isNeedRequestStoragePermissionOnAndroid();
    if(Platform.isAndroid && needRequestPermission) {
      final status = await Permission.storage.status;
      switch (status) {
        case PermissionStatus.granted:
          return true;
        case PermissionStatus.permanentlyDenied:
          return false;
        default: {
          final requested = await Permission.storage.request();
          switch (requested) {
            case PermissionStatus.granted:
              return true;
            default:
              return false;
          }
        }
      }
    } else {
      return true;
    }
  }

}