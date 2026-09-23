import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_button.dart';
import 'interests_screen.dart';

enum LocationScreenState {
  detecting,
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  ready,
}

class LocationMapScreen extends StatefulWidget {
  final AuthController authController;
  final LatLng? initialPosition;

  const LocationMapScreen({
    super.key,
    required this.authController,
    this.initialPosition,
  });

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _locationChannel =
      MethodChannel('com.tolii.app/location_settings');

  final MapController _mapController = MapController();

  LocationScreenState _screenState = LocationScreenState.detecting;

  LatLng? _userGpsPosition;
  LatLng _mapCenterPosition = const LatLng(21.7645, 72.1519);

  bool _isAtCurrentGps = true;
  bool _isResolvingAddress = false;

  String _resolvedAddress = '';
  String _resolvedLine1 = '';
  String _resolvedLine2 = '';
  String _resolvedLine3 = '';
  String _resolvedStreet = '';
  String _resolvedArea = '';
  String _resolvedCity = '';
  String _resolvedState = '';
  String _resolvedPincode = '';

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialPosition != null) {
      _mapCenterPosition = widget.initialPosition!;
      _screenState = LocationScreenState.ready;
      _isAtCurrentGps = false;
      _fetchAddressForCoordinates(widget.initialPosition!.latitude, widget.initialPosition!.longitude);
    } else {
      _initLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Automatically re-check location services & permissions when returning to TOLI
      _initLocation();
    }
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _screenState = LocationScreenState.detecting;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _screenState = LocationScreenState.serviceDisabled;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _screenState = LocationScreenState.permissionDenied;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _screenState = LocationScreenState.permissionPermanentlyDenied;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final gpsLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _userGpsPosition = gpsLatLng;
        _mapCenterPosition = gpsLatLng;
        _isAtCurrentGps = true;
        _screenState = LocationScreenState.ready;
      });

      // Initial reverse geocoding for GPS location
      _fetchAddressForCoordinates(gpsLatLng.latitude, gpsLatLng.longitude);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _screenState = LocationScreenState.serviceDisabled;
      });
    }
  }

  Future<void> _openLocationSettings() async {
    debugPrint('OPEN_LOCATION_SETTINGS_BUTTON_TAPPED');
    HapticFeedback.lightImpact();

    try {
      final bool? success = await _locationChannel.invokeMethod<bool>('openLocationSettings');
      if (success == true) {
        return;
      }
    } catch (e) {
      debugPrint('OPEN_LOCATION_SETTINGS_METHODCHANNEL_FAILED: $e');
    }

    try {
      final bool opened = await Geolocator.openLocationSettings();
      if (opened) return;
    } catch (_) {}

    try {
      await AppSettings.openAppSettings(type: AppSettingsType.location);
      return;
    } catch (_) {}

    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  Future<void> _openAppSettings() async {
    debugPrint('OPEN_APP_SETTINGS_BUTTON_TAPPED');
    HapticFeedback.lightImpact();

    try {
      final bool? success = await _locationChannel.invokeMethod<bool>('openAppSettings');
      if (success == true) return;
    } catch (_) {}

    try {
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
    } catch (_) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
    }
  }

  Future<void> _fetchAddressForCoordinates(double lat, double lon) async {
    if (!mounted) return;
    setState(() {
      _isResolvingAddress = true;
    });

    try {
      final client = HttpClient();
      client.userAgent = 'ToliiApp/1.0 (com.tolii.app)';
      final request = await client.getUrl(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody);
        final addressMap = data['address'] as Map<String, dynamic>?;

        if (addressMap != null) {
          // Parse House / Building / Block
          String houseOrBlock = '';
          final rawBlock = addressMap['block']?.toString().trim() ?? '';
          final rawHouseNum = addressMap['house_number']?.toString().trim() ?? '';
          final rawBuilding = (addressMap['building'] ?? addressMap['house_name'])?.toString().trim() ?? '';

          if (rawBlock.isNotEmpty) {
            houseOrBlock = rawBlock.toLowerCase().startsWith('block') ? rawBlock : 'Block $rawBlock';
          } else if (rawHouseNum.isNotEmpty) {
            houseOrBlock = rawHouseNum;
          } else if (rawBuilding.isNotEmpty) {
            houseOrBlock = rawBuilding;
          }

          // Parse Road / Street
          final roadStr = (addressMap['road'] ?? addressMap['street'] ?? addressMap['pedestrian'] ?? '').toString().trim();

          // LINE 1: House/Building/Block + Road/Street
          String line1 = '';
          if (houseOrBlock.isNotEmpty && roadStr.isNotEmpty) {
            line1 = '$houseOrBlock, $roadStr';
          } else if (houseOrBlock.isNotEmpty) {
            line1 = houseOrBlock;
          } else if (roadStr.isNotEmpty) {
            line1 = roadStr;
          }

          // Parse Locality / Neighbourhood / Area
          final areaStr = (addressMap['neighbourhood'] ??
                  addressMap['suburb'] ??
                  addressMap['locality'] ??
                  addressMap['residential'] ??
                  addressMap['quarter'] ??
                  addressMap['village'] ??
                  '')
              .toString()
              .trim();

          // Parse City
          final cityStr = (addressMap['city'] ??
                  addressMap['town'] ??
                  addressMap['city_district'] ??
                  addressMap['state_district'] ??
                  addressMap['county'] ??
                  '')
              .toString()
              .trim();

          // LINE 2: Locality/Area + City
          String line2 = '';
          if (areaStr.isNotEmpty && cityStr.isNotEmpty && areaStr.toLowerCase() != cityStr.toLowerCase()) {
            line2 = '$areaStr, $cityStr';
          } else if (areaStr.isNotEmpty) {
            line2 = areaStr;
          } else if (cityStr.isNotEmpty) {
            line2 = cityStr;
          }

          // Parse State & Postcode
          final stateStr = (addressMap['state'] ?? '').toString().trim();
          final postcodeStr = (addressMap['postcode'] ?? '').toString().trim();

          // LINE 3: State + Postcode
          String line3 = '';
          if (stateStr.isNotEmpty && postcodeStr.isNotEmpty) {
            line3 = '$stateStr $postcodeStr';
          } else if (stateStr.isNotEmpty) {
            line3 = stateStr;
          } else if (postcodeStr.isNotEmpty) {
            line3 = postcodeStr;
          }

          // Fallback parsing if line1 is empty
          List<String> validLines = [line1, line2, line3].where((l) => l.isNotEmpty).toList();

          if (validLines.isEmpty && data['display_name'] != null) {
            final rawParts = (data['display_name'] as String)
                .split(',')
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList();
            if (rawParts.isNotEmpty) {
              line1 = rawParts[0];
              if (rawParts.length >= 2) line2 = rawParts.sublist(1, rawParts.length > 3 ? 3 : rawParts.length).join(', ');
              if (rawParts.length >= 4) line3 = rawParts.sublist(3).take(2).join(' ');
              validLines = [line1, line2, line3].where((l) => l.isNotEmpty).toList();
            }
          }

          final resLine1 = validLines.isNotEmpty ? validLines[0] : 'Selected Location';
          final resLine2 = validLines.length > 1 ? validLines[1] : '';
          final resLine3 = validLines.length > 2 ? validLines[2] : '';
          final fullAddr = validLines.join(', ');

          if (!mounted) return;
          setState(() {
            _resolvedLine1 = resLine1;
            _resolvedLine2 = resLine2;
            _resolvedLine3 = resLine3;
            _resolvedStreet = roadStr.isNotEmpty ? roadStr : houseOrBlock;
            _resolvedArea = areaStr;
            _resolvedCity = cityStr;
            _resolvedState = stateStr;
            _resolvedPincode = postcodeStr;
            _resolvedAddress = fullAddr;
            _isResolvingAddress = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('REVERSE_GEOCODE_ERROR: $e');
    }

    if (!mounted) return;
    setState(() {
      _resolvedLine1 = 'Location details unavailable';
      _resolvedLine2 = 'Coordinates: (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})';
      _resolvedLine3 = '';
      _resolvedAddress = 'Coordinates: (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})';
      _isResolvingAddress = false;
    });
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    _mapCenterPosition = camera.center;

    if (_userGpsPosition != null) {
      final distance = Geolocator.distanceBetween(
        _userGpsPosition!.latitude,
        _userGpsPosition!.longitude,
        camera.center.latitude,
        camera.center.longitude,
      );
      _isAtCurrentGps = distance < 50;
    } else {
      _isAtCurrentGps = false;
    }

    if (hasGesture) {
      setState(() {
        _isResolvingAddress = true;
      });

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _fetchAddressForCoordinates(camera.center.latitude, camera.center.longitude);
      });
    }
  }

  Future<void> _reCenterToMyLocation() async {
    HapticFeedback.lightImpact();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _initLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await _initLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final gpsLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _userGpsPosition = gpsLatLng;
        _mapCenterPosition = gpsLatLng;
        _isAtCurrentGps = true;
        _isResolvingAddress = true;
      });

      _mapController.move(gpsLatLng, 16.0);
      _fetchAddressForCoordinates(gpsLatLng.latitude, gpsLatLng.longitude);
    } catch (e) {
      debugPrint('RECENTER_GPS_ERROR: $e');
      if (_userGpsPosition != null) {
        _mapController.move(_userGpsPosition!, 16.0);
        _fetchAddressForCoordinates(_userGpsPosition!.latitude, _userGpsPosition!.longitude);
      } else {
        await _initLocation();
      }
    }
  }

  void _onConfirmLocation() {
    HapticFeedback.mediumImpact();

    // Store selected center coordinates & reverse-geocoded details
    widget.authController.setMapSelectedLocation(
      latitude: _mapCenterPosition.latitude,
      longitude: _mapCenterPosition.longitude,
      address: _resolvedAddress.isNotEmpty ? _resolvedAddress : 'Selected Location',
      street: _resolvedStreet,
      area: _resolvedArea,
      city: _resolvedCity,
      state: _resolvedState,
      pincode: _resolvedPincode,
    );

    // Navigate to next onboarding step (Interests)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            InterestsScreen(authController: widget.authController),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Choose your location',
          style: AppTypography.headline.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_screenState) {
      case LocationScreenState.detecting:
        return _buildDetectingState();
      case LocationScreenState.permissionDenied:
        return _buildPermissionDeniedState();
      case LocationScreenState.permissionPermanentlyDenied:
        return _buildPermissionPermanentlyDeniedState();
      case LocationScreenState.serviceDisabled:
        return _buildServiceDisabledState();
      case LocationScreenState.ready:
        return _buildMapPickerState();
    }
  }

  // 1. Loading State
  Widget _buildDetectingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF4FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Detecting your location...',
            style: AppTypography.titleMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fetching precise GPS position for TOLI',
            style: AppTypography.caption.copyWith(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Permission Denied State
  Widget _buildPermissionDeniedState() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: Color(0xFFDC2626),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Location permission is required',
                style: AppTypography.headline.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Allow location access to find your current position.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              CustomButton(
                text: 'Allow Location',
                height: 50,
                onPressed: _initLocation,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Enter Location Manually',
                  style: AppTypography.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Permission Permanently Denied State
  Widget _buildPermissionPermanentlyDeniedState() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Color(0xFFDC2626),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Location permission denied',
                style: AppTypography.headline.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Location permission is permanently disabled. Please enable it in App Settings.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              CustomButton(
                text: 'Open App Settings',
                height: 50,
                onPressed: _openAppSettings,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Enter Location Manually',
                  style: AppTypography.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Service Disabled State
  Widget _buildServiceDisabledState() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_disabled_rounded,
                  color: Color(0xFFEA580C),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Turn on location services',
                style: AppTypography.headline.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enable location services to detect your position.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              CustomButton(
                text: 'Open Location Settings',
                height: 50,
                onPressed: _openLocationSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _cartoApiKey = String.fromEnvironment('CARTO_API_KEY', defaultValue: '');

  String get _mapTileUrl {
    if (_cartoApiKey.isNotEmpty) {
      return 'https://basemaps.cartocdn.com/rastertiles/light_all/{z}/{x}/{y}.png?api_key=$_cartoApiKey';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  // 5. Main Interactive Map Picker (TOLI Themed Clean Light Map)
  Widget _buildMapPickerState() {
    return Stack(
      children: [
        // Clean TOLI-themed minimal light map tiles (CARTO if key provided, clean OSM fallback)
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenterPosition,
            initialZoom: 16.0,
            onPositionChanged: _onMapPositionChanged,
          ),
          children: [
            TileLayer(
              urlTemplate: _mapTileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.tolii.app',
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  _cartoApiKey.isNotEmpty
                      ? '© CARTO © OpenStreetMap contributors'
                      : '© OpenStreetMap contributors',
                ),
              ],
            ),
            // Live GPS position subtle blue ring indicator
            if (_userGpsPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userGpsPosition!,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Fixed Selection Pin in the CENTER of the map
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge above pin
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _isResolvingAddress
                            ? 'Finding location...'
                            : (_isAtCurrentGps ? 'Your Location' : 'Selected Location'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 42,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom Controls Layout (Recenter Button stacked strictly above the Bottom Location Sheet)
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Circular Current Location / Recenter Button
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _reCenterToMyLocation,
                      child: const Center(
                        child: Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom White TOLI Confirmation Sheet (NO Grey Drag Handle)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label: "Your current location" or "Selected location"
                      Text(
                        _isAtCurrentGps ? 'Your current location' : 'Selected location',
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Location Icon + Address Hierarchy
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isResolvingAddress) ...[
                                  Text(
                                    'Finding this location...',
                                    style: AppTypography.headline.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Updating address...',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ] else ...[
                                  // Line 1: House/Block + Road/Street
                                  Text(
                                    _resolvedLine1.isNotEmpty ? _resolvedLine1 : 'Selected Location',
                                    style: AppTypography.headline.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                      height: 1.3,
                                    ),
                                  ),
                                  // Line 2: Locality/Area + City
                                  if (_resolvedLine2.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      _resolvedLine2,
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                  // Line 3: State + Postcode
                                  if (_resolvedLine3.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _resolvedLine3,
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Confirm Location Button
                      CustomButton(
                        text: 'Confirm Location',
                        height: 50,
                        onPressed: _onConfirmLocation,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
