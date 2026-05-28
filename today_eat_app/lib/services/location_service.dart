// 对外接口：
// - LocationResult
// - LocationService.getCurrentAddress

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({
    required this.success,
    required this.message,
    this.displayText,
    this.province,
    this.city,
    this.district,
    this.latitude,
    this.longitude,
    this.usedLastKnown = false,
  });

  final bool success;
  final String message;
  final String? displayText;
  final String? province;
  final String? city;
  final String? district;
  final double? latitude;
  final double? longitude;
  final bool usedLastKnown;
}

class LocationService {
  static const Duration _freshLocationTimeLimit = Duration(seconds: 5);

  /// [对外接口] 获取当前粗粒度地点与经纬度。
  Future<LocationResult> getCurrentAddress({
    ValueChanged<LocationResult>? onUpdate,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[GPS] serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) {
      return const LocationResult(success: false, message: '定位服务未开启');
    }

    var permission = await Geolocator.checkPermission();
    debugPrint('[GPS] initialPermission=$permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[GPS] requestedPermission=$permission');
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult(success: false, message: '定位权限被拒绝');
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
        success: false,
        message: '定位权限被永久拒绝，请在系统设置中打开',
      );
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      debugPrint(
        '[GPS] immediate lastKnown lat=${lastKnown.latitude}, lng=${lastKnown.longitude}',
      );
      final cachedResult = await _resolvePosition(
        lastKnown,
        prefix: '已使用最近一次位置',
        usedLastKnown: true,
      );
      unawaited(_refreshCurrentAddress(onUpdate: onUpdate));
      return cachedResult;
    }

    return _fetchFreshAddress();
  }

  Future<void> _refreshCurrentAddress({
    ValueChanged<LocationResult>? onUpdate,
  }) async {
    if (onUpdate == null) {
      return;
    }

    final freshResult = await _fetchFreshAddress();
    if (!freshResult.success) {
      debugPrint('[GPS] ignore failed background refresh');
      return;
    }
    onUpdate(freshResult);
  }

  Future<LocationResult> _fetchFreshAddress() async {
    try {
      debugPrint('[GPS] begin getCurrentPosition');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _freshLocationTimeLimit,
        ),
      );
      debugPrint(
        '[GPS] position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}',
      );
      return await _resolvePosition(
        position,
        prefix: null,
        usedLastKnown: false,
      );
    } on LocationServiceDisabledException catch (error, stackTrace) {
      debugPrint('[GPS] LocationServiceDisabledException error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return const LocationResult(success: false, message: '定位服务未开启');
    } on PermissionDeniedException catch (error, stackTrace) {
      debugPrint('[GPS] PermissionDeniedException error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return const LocationResult(success: false, message: '定位权限不足');
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[GPS] TimeoutException error=$error');
      debugPrintStack(stackTrace: stackTrace);
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint(
          '[GPS] fallback lastKnown lat=${lastKnown.latitude}, lng=${lastKnown.longitude}',
        );
        return await _resolvePosition(
          lastKnown,
          prefix: '定位较慢，已使用最近一次位置',
          usedLastKnown: true,
        );
      }
      return const LocationResult(success: false, message: '定位超时，请到空旷处重试');
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '[GPS] PlatformException code=${error.code} message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      return LocationResult(
        success: false,
        message: '系统定位异常：${error.message ?? error.code}',
      );
    } catch (error, stackTrace) {
      debugPrint('[GPS] unknown error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return LocationResult(success: false, message: '定位失败：${error.runtimeType}');
    }
  }

  Future<LocationResult> _resolvePosition(
    Position position, {
    required String? prefix,
    required bool usedLastKnown,
  }) async {
    try {
      await setLocaleIdentifier('zh_CN');
      debugPrint('[GPS] locale set to zh_CN');
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      debugPrint('[GPS] placemarks count=${placemarks.length}');
      if (placemarks.isEmpty) {
        return _buildCoordinateFallback(
          position,
          prefix: prefix ?? '已获取坐标，暂未解析到区级地点',
          usedLastKnown: usedLastKnown,
        );
      }

      final placemark = placemarks.first;
      final province = _clean(placemark.administrativeArea);
      final city = _clean(placemark.locality) ?? _clean(placemark.subAdministrativeArea);
      final district = _clean(placemark.subLocality) ?? _clean(placemark.locality);
      final coarseText = _formatCoarseAddress(
        province: province,
        city: city,
        district: district,
      );

      if (coarseText == null) {
        return _buildCoordinateFallback(
          position,
          prefix: prefix ?? '已获取坐标，暂未解析到区级地点',
          usedLastKnown: usedLastKnown,
        );
      }

      debugPrint('[GPS] resolved address=$coarseText');
      final displayText = prefix == null ? coarseText : '$prefix：$coarseText';
      return LocationResult(
        success: true,
        message: displayText,
        displayText: coarseText,
        province: province,
        city: city,
        district: district,
        latitude: position.latitude,
        longitude: position.longitude,
        usedLastKnown: usedLastKnown,
      );
    } on NoResultFoundException catch (error, stackTrace) {
      debugPrint('[GPS] NoResultFoundException error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return _buildCoordinateFallback(
        position,
        prefix: prefix ?? '已获取坐标，暂未解析到区级地点',
        usedLastKnown: usedLastKnown,
      );
    } catch (error, stackTrace) {
      debugPrint('[GPS] reverse lookup failed error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return _buildCoordinateFallback(
        position,
        prefix: prefix ?? '已获取坐标，暂未解析到区级地点',
        usedLastKnown: usedLastKnown,
      );
    }
  }

  LocationResult _buildCoordinateFallback(
    Position position, {
    required String prefix,
    required bool usedLastKnown,
  }) {
    return LocationResult(
      success: true,
      message:
          '$prefix：${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      latitude: position.latitude,
      longitude: position.longitude,
      usedLastKnown: usedLastKnown,
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _formatCoarseAddress({
    required String? province,
    required String? city,
    required String? district,
  }) {
    if (city != null && district != null && district != city) {
      return '$city $district';
    }
    if (city != null) {
      return city;
    }
    if (province != null) {
      return province;
    }
    return null;
  }
}
