import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';
import '../models/user_profile_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/username_repository.dart';
import '../services/otp_service.dart';
import '../utils/username_validator.dart';

class AuthController extends ChangeNotifier {
  static final AuthController _instance = AuthController._internal();
  factory AuthController() => _instance;
  static AuthController get instance => _instance;

  final UserRepository _userRepository = UserRepository();
  final UsernameRepository _usernameRepository = UsernameRepository();

  final AuthModel _state = AuthModel();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isFirebaseAuthenticated {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (e) {
      return false;
    }
  }

  Timer? _timer;
  int _resendCountdown = 23;
  bool _canResend = false;

  AuthModel get state => _state;
  int get resendCountdown => _resendCountdown;
  bool get canResend => _canResend;
  String get formattedCountdown {
    final minutes = (_resendCountdown ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendCountdown % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Read-only preview username generated dynamically from First Name + Last Name
  String get previewUsername => UsernameValidator.generateBaseUsername(_state.firstName, _state.lastName);

  // Step Navigation
  void setStep(int step) {
    if (step >= 1 && step <= 5) {
      _state.currentStep = step;
      notifyListeners();
    }
  }

  // Auth Mode (phone vs email)
  void setAuthMode(String mode) {
    _state.authMode = mode;
    _state.phoneError = null;
    _state.emailError = null;
    notifyListeners();
  }

  // Email Validation
  bool validateEmail(String email) {
    final trimmed = email.trim();
    _state.email = trimmed;

    if (trimmed.isEmpty) {
      _state.emailError = 'Please enter your email address';
      notifyListeners();
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmed)) {
      _state.emailError = 'Please enter a valid email address';
      notifyListeners();
      return false;
    }

    _state.emailError = null;
    notifyListeners();
    return true;
  }

  void clearEmailError() {
    if (_state.emailError != null) {
      _state.emailError = null;
      notifyListeners();
    }
  }

  // Phone Validation
  bool validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    _state.rawPhoneNumber = phone;
    _state.phoneNumber = '+91 $phone'.trim();

    if (digits.isEmpty) {
      _state.phoneError = 'Please enter your mobile number';
      notifyListeners();
      return false;
    }

    if (digits.length < 10) {
      _state.phoneError = 'Please enter a valid 10-digit mobile number';
      notifyListeners();
      return false;
    }

    _state.phoneError = null;
    notifyListeners();
    return true;
  }

  void clearPhoneError() {
    if (_state.phoneError != null) {
      _state.phoneError = null;
      notifyListeners();
    }
  }

  void toggleWhatsappOptIn() {
    _state.isWhatsappOptedIn = !_state.isWhatsappOptedIn;
    notifyListeners();
  }

  Timer? _usernameDebounceTimer;
  int _usernameRequestId = 0;

  // Send OTP (Step 1 -> Step 2)
  Future<bool> sendOtp() async {
    _state.isLoading = true;
    _state.emailError = null;
    _state.phoneError = null;
    notifyListeners();

    try {
      if (_state.authMode == 'email') {
        if (_state.email.trim().isEmpty) {
          _state.isLoading = false;
          _state.emailError = 'Please enter your email address';
          notifyListeners();
          return false;
        }

        final response = await OtpService().requestOtp(_state.email.trim());
        _state.isLoading = false;

        if (!response.success) {
          _state.emailError = response.message;
          notifyListeners();
          return false;
        }

        _state.otpError = null;
        startResendTimer(seconds: 300);
        _state.currentStep = 2;
        notifyListeners();
        return true;
      } else {
        if (_state.rawPhoneNumber.trim().isEmpty) {
          _state.isLoading = false;
          _state.phoneError = 'Please enter your mobile number';
          notifyListeners();
          return false;
        }

        await Future.delayed(const Duration(milliseconds: 350));
        _state.isLoading = false;
        _state.otpError = null;
        startResendTimer(seconds: 23);
        _state.currentStep = 2;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthController] sendOtp exception: $e');
      _state.emailError = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      _state.isLoading = false;
      notifyListeners();
    }
  }

  void startResendTimer({int seconds = 23}) {
    _timer?.cancel();
    _resendCountdown = seconds;
    _canResend = false;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 1) {
        _resendCountdown--;
        notifyListeners();
      } else {
        _resendCountdown = 0;
        _canResend = true;
        _timer?.cancel();
        notifyListeners();
      }
    });
  }

  void updateOtp(String otp) {
    _state.otp = otp;
    if (_state.otpError != null) {
      _state.otpError = null;
    }
    notifyListeners();
  }

  // Verify OTP (Step 2 -> Step 3)
  Future<bool> verifyOtp() async {
    if (_state.otp.isEmpty || _state.otp.length < 6) {
      _state.otpError = 'Please enter complete 6-digit OTP';
      notifyListeners();
      return false;
    }

    _state.isLoading = true;
    _state.otpError = null;
    notifyListeners();

    try {
      if (_state.authMode == 'email') {
        final response = await OtpService().verifyOtp(
          _state.email.trim(),
          _state.otp.trim(),
        );

        if (!response.success) {
          _state.isLoading = false;
          _state.otpError = response.message;
          notifyListeners();
          return false;
        }

        // If Firebase Custom Token is provided, authenticate with Firebase Auth
        if (response.firebaseToken != null && response.firebaseToken!.isNotEmpty) {
          try {
            final userCredential = await FirebaseAuth.instance.signInWithCustomToken(
              response.firebaseToken!,
            );
            final user = userCredential.user;

            if (user != null) {
              final remoteProfile = await _userRepository.getUserProfile(user.uid);
              if (remoteProfile != null) {
                _state.firstName = remoteProfile.firstName;
                _state.lastName = remoteProfile.lastName;
                _state.username = remoteProfile.username;
                _state.email = remoteProfile.email;
                _state.phoneNumber = remoteProfile.phoneNumber;
                _state.selectedCity = remoteProfile.selectedCity;
                _state.gender = remoteProfile.gender;
                _state.avatarUrl = remoteProfile.photoUrl;
                _state.selectedInterests = List<String>.from(remoteProfile.interests);
                _state.isProfileComplete = remoteProfile.isProfileComplete;

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('tolii_is_profile_complete', remoteProfile.isProfileComplete);
              } else {
                _state.isProfileComplete = false;
              }
            }
          } catch (authError) {
            debugPrint('[AUTH] Firebase signInWithCustomToken error: $authError');
          }
        }

        _state.isLoading = false;
        _state.otpError = null;
        if (!_state.isProfileComplete) {
          _state.currentStep = 3;
        }
        notifyListeners();
        return true;
      } else {
        await Future.delayed(const Duration(milliseconds: 350));
        _state.isLoading = false;
        _state.otpError = null;
        _state.currentStep = 3;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthController] verifyOtp exception: $e');
      _state.otpError = 'Verification failed. Please try again.';
      return false;
    } finally {
      _state.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp() async {
    if (!_canResend) return;

    _state.otp = '';
    _state.otpError = null;
    _state.isLoading = true;
    notifyListeners();

    try {
      if (_state.authMode == 'email') {
        final response = await OtpService().requestOtp(_state.email.trim());
        _state.isLoading = false;

        if (!response.success) {
          _state.otpError = response.message;
          notifyListeners();
          return;
        }

        startResendTimer(seconds: 300);
        notifyListeners();
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        _state.isLoading = false;
        startResendTimer(seconds: 23);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthController] resendOtp exception: $e');
      _state.otpError = 'Failed to resend code. Please try again.';
    } finally {
      _state.isLoading = false;
      notifyListeners();
    }
  }

  // Step 3: Location Management
  void detectLocation() {
    _state.isLocationDetected = true;
    _state.pincodeError = null;
    notifyListeners();
  }

  void setMapSelectedLocation({
    required double latitude,
    required double longitude,
    required String address,
    String? street,
    String? area,
    String? city,
    String? state,
    String? pincode,
  }) {
    _state.latitude = latitude;
    _state.longitude = longitude;
    if (city != null && city.isNotEmpty) {
      _state.selectedCity = city;
    }
    if (state != null && state.isNotEmpty) {
      _state.selectedState = state;
    }
    if (street != null && street.isNotEmpty) {
      _state.streetAddress = street;
    }
    if (area != null && area.isNotEmpty) {
      _state.areaLocality = area;
    } else if (address.isNotEmpty) {
      _state.areaLocality = address.split(',').first.trim();
    }
    if (pincode != null && pincode.isNotEmpty) {
      _state.pincode = pincode;
    }
    _state.locationSummary = address.isNotEmpty ? address : (_state.selectedCity.isNotEmpty ? _state.selectedCity : 'Location Set');
    _state.isLocationDetected = true;
    _state.pincodeError = null;
    notifyListeners();
  }

  void setManualLocation({
    required String state,
    required String city,
    required String locality,
    String street = '',
    required String pincode,
    String landmark = '',
  }) {
    _state.selectedState = state;
    _state.selectedCity = city;
    _state.areaLocality = locality;
    _state.streetAddress = street;
    _state.pincode = pincode;
    _state.landmark = landmark;
    _state.locationSummary = locality.isNotEmpty ? '$locality, $city' : '$city, India';
    _state.isLocationDetected = false;
    notifyListeners();
  }

  bool validatePincode(String pincode) {
    final digits = pincode.replaceAll(RegExp(r'\D'), '');
    _state.pincode = pincode;

    if (digits.length != 6) {
      _state.pincodeError = 'Enter a valid 6-digit pincode';
      notifyListeners();
      return false;
    }

    _state.pincodeError = null;
    notifyListeners();
    return true;
  }

  void clearPincodeError() {
    if (_state.pincodeError != null) {
      _state.pincodeError = null;
      notifyListeners();
    }
  }

  Future<bool> confirmLocation() async {
    _state.isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 250));
    _state.isLoading = false;
    _state.currentStep = 4;
    notifyListeners();
    return true;
  }

  // Step 4: Interests Management
  void toggleInterest(String interest) {
    if (_state.selectedInterests.contains(interest)) {
      _state.selectedInterests.remove(interest);
    } else {
      _state.selectedInterests.add(interest);
    }
    notifyListeners();
  }

  bool isInterestSelected(String interest) {
    return _state.selectedInterests.contains(interest);
  }

  Future<bool> continueFromInterests() async {
    _state.currentStep = 5;
    notifyListeners();
    return true;
  }

  // Step 5: Profile Creation
  void updateProfileNames({required String firstName, required String lastName}) {
    _state.firstName = firstName;
    _state.lastName = lastName;
    notifyListeners();
  }

  void updateUsername(String username) {
    final norm = UsernameValidator.normalize(username);

    if (norm == _state.username &&
        _state.checkedUsername == norm &&
        _state.usernameValidationStatus == UsernameValidationStatus.available) {
      return;
    }

    _usernameDebounceTimer?.cancel();
    _state.username = norm;
    _state.checkedUsername = null;

    if (norm.isEmpty) {
      _state.usernameValidationStatus = UsernameValidationStatus.idle;
      _state.isUsernameAvailable = false;
      _state.usernameError = null;
      notifyListeners();
      return;
    }

    final formatError = UsernameValidator.getValidationError(norm);
    if (formatError != null) {
      _state.usernameValidationStatus = UsernameValidationStatus.invalid;
      _state.isUsernameAvailable = false;
      _state.usernameError = formatError;
      notifyListeners();
      return;
    }

    _state.usernameValidationStatus = UsernameValidationStatus.checking;
    _state.isUsernameAvailable = false;
    _state.usernameError = null;
    notifyListeners();

    _usernameRequestId++;
    final currentRequestId = _usernameRequestId;

    _usernameDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final checkResult = await _usernameRepository.checkUsernameAvailabilityRemote(
        norm,
        currentUid: _auth.currentUser?.uid,
      );

      if (currentRequestId == _usernameRequestId && _state.username == norm) {
        if (checkResult == UsernameCheckResult.error) {
          _state.usernameValidationStatus = UsernameValidationStatus.error;
          _state.isUsernameAvailable = false;
          _state.checkedUsername = null;
          _state.usernameError = 'Unable to check availability. Please try again.';
        } else if (checkResult == UsernameCheckResult.taken) {
          _state.usernameValidationStatus = UsernameValidationStatus.taken;
          _state.isUsernameAvailable = false;
          _state.checkedUsername = norm;
          _state.usernameError = UsernameValidator.isReserved(norm)
              ? 'Username is not available'
              : 'Username is already taken';
        } else {
          _state.usernameValidationStatus = UsernameValidationStatus.available;
          _state.isUsernameAvailable = true;
          _state.checkedUsername = norm;
          _state.usernameError = null;
        }
        notifyListeners();
      }
    });
  }

  List<String> getUsernameSuggestions() {
    final rawName = _state.googleDisplayName ??
        '${_state.firstName} ${_state.lastName}'.trim();
    if (rawName.trim().isEmpty) return [];

    final cleanName = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanName.isEmpty) return [];

    final parts = cleanName.split(' ');
    final first = parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join('') : '';

    final Set<String> suggestions = {};
    if (last.isNotEmpty) {
      suggestions.add('$first$last');
      suggestions.add('$first.$last');
      suggestions.add('${first}_$last');
      suggestions.add('$first${last}01');
    } else {
      suggestions.add('${first}01');
      suggestions.add('${first}_tolii');
      suggestions.add('real_$first');
    }

    final validFormatRegex = RegExp(r'^[a-z0-9_.]+$');
    return suggestions
        .where((s) => s.length >= 3 && s.length <= 30 && validFormatRegex.hasMatch(s))
        .take(4)
        .toList();
  }

  void updateGender(String? gender) {
    _state.gender = gender;
    notifyListeners();
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthController._internal() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      _auth.userChanges().listen((User? user) {
        if (user != null) {
          _state.googleEmail = user.email;
          _state.googleDisplayName = user.displayName;
          _state.googlePhotoUrl = user.photoURL;

          if (user.email != null && user.email!.isNotEmpty && _state.email.isEmpty) {
            _state.email = user.email!;
          }
          if (user.displayName != null && user.displayName!.isNotEmpty && _state.firstName.isEmpty) {
            final parts = user.displayName!.trim().split(RegExp(r'\s+'));
            _state.firstName = parts.first;
            if (parts.length > 1) {
              _state.lastName = parts.sublist(1).join(' ');
            }
          }
          if (user.photoURL != null && user.photoURL!.isNotEmpty && (_state.avatarUrl == null || _state.avatarUrl!.isEmpty)) {
            _state.avatarUrl = user.photoURL;
          }
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('FirebaseAuth userChanges listener omitted in test environment: $e');
    }
  }

  Future<void> init() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _state.googleEmail = user.email;
        _state.googleDisplayName = user.displayName;
        _state.googlePhotoUrl = user.photoURL;

        // 1. Try reading profile from Firestore (Source of Truth)
        final remoteProfile = await _userRepository.getUserProfile(user.uid);
        if (remoteProfile != null) {
          _state.firstName = remoteProfile.firstName;
          _state.lastName = remoteProfile.lastName;
          _state.username = remoteProfile.username;
          _state.email = remoteProfile.email.isNotEmpty ? remoteProfile.email : (user.email ?? '');
          _state.phoneNumber = remoteProfile.phoneNumber.isNotEmpty ? remoteProfile.phoneNumber : (user.phoneNumber ?? '');
          _state.selectedCity = remoteProfile.selectedCity;
          _state.gender = remoteProfile.gender;
          _state.avatarUrl = remoteProfile.photoUrl ?? user.photoURL;
          _state.selectedInterests = List<String>.from(remoteProfile.interests);
          _state.isProfileComplete = remoteProfile.isProfileComplete;

          // Sync local SharedPreferences cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('tolii_is_profile_complete', remoteProfile.isProfileComplete);
          await prefs.setString('tolii_user_first_name', _state.firstName);
          await prefs.setString('tolii_user_last_name', _state.lastName);
          await prefs.setString('tolii_user_username', _state.username);
          await prefs.setString('tolii_user_email', _state.email);
          await prefs.setString('tolii_user_phone', _state.phoneNumber);
          await prefs.setString('tolii_user_city', _state.selectedCity);
          if (_state.gender != null) await prefs.setString('tolii_user_gender', _state.gender!);
        } else {
          // New user defaults (zero pre-selected interests)
          _state.selectedInterests = [];
          if (user.email != null && user.email!.isNotEmpty && _state.email.isEmpty) {
            _state.email = user.email!;
          }
          if (user.displayName != null && user.displayName!.isNotEmpty && _state.firstName.isEmpty) {
            final parts = user.displayName!.trim().split(RegExp(r'\s+'));
            _state.firstName = parts.first;
            if (parts.length > 1) {
              _state.lastName = parts.sublist(1).join(' ');
            }
          }
          if (user.photoURL != null && user.photoURL!.isNotEmpty) {
            _state.avatarUrl = user.photoURL;
          }
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty && _state.phoneNumber.isEmpty) {
            _state.phoneNumber = user.phoneNumber!;
            _state.rawPhoneNumber = user.phoneNumber!;
          }
          _state.isProfileComplete = false;
        }
      }
    } catch (e) {
      debugPrint('Error initializing AuthController: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? location,
    String? gender,
    String? profileImagePath,
    List<String>? interestedActivities,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _state.authError = 'No authenticated user found.';
      notifyListeners();
      return false;
    }

    if (firstName != null) _state.firstName = firstName.trim();
    if (lastName != null) _state.lastName = lastName.trim();
    if (email != null) _state.email = email.trim();
    if (phone != null) _state.phoneNumber = phone.trim();
    if (location != null) _state.selectedCity = location.trim();
    if (gender != null) _state.gender = gender;
    if (profileImagePath != null) _state.profileImagePath = profileImagePath;
    if (interestedActivities != null) _state.selectedInterests = List.from(interestedActivities);

    if (_state.firstName.isEmpty) {
      _state.usernameError = 'Please enter your first name';
      notifyListeners();
      return false;
    }

    final oldUsername = _state.username;

    // 1. Automatically generate and claim unique username in Firestore transaction
    try {
      final assignedUsername = await _usernameRepository.generateAndClaimUniqueUsername(
        uid: user.uid,
        firstName: _state.firstName,
        lastName: _state.lastName,
        oldUsername: oldUsername.isNotEmpty ? oldUsername : null,
      );
      _state.username = assignedUsername;
      _state.checkedUsername = assignedUsername;
      _state.isUsernameAvailable = true;
      _state.usernameValidationStatus = UsernameValidationStatus.available;
      _state.usernameError = null;
    } catch (e) {
      debugPrint('Error during automatic username generation/claim in Firestore transaction: $e');
      _state.usernameError = 'Unable to save profile. Please check network/permissions and try again.';
      _state.isLoading = false;
      notifyListeners();
      return false;
    }

    _state.isProfileComplete = true;

    // 2. Save complete user profile to Firestore users/{uid}
    final userProfile = UserProfileModel(
      uid: user.uid,
      firstName: _state.firstName,
      lastName: _state.lastName,
      username: _state.username,
      normalizedUsername: _state.username.trim().toLowerCase(),
      email: _state.email,
      phoneNumber: _state.phoneNumber,
      photoUrl: _state.avatarUrl ?? user.photoURL,
      selectedCity: _state.selectedCity,
      gender: _state.gender,
      interests: _state.selectedInterests,
      isProfileComplete: true,
    );

    final savedRemote = await _userRepository.saveUserProfile(userProfile);
    if (!savedRemote) {
      _state.authError = 'Failed to save profile to server.';
      notifyListeners();
      return false;
    }

    // 3. Sync SharedPreferences local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tolii_is_profile_complete', true);
      await prefs.setString('tolii_user_first_name', _state.firstName);
      await prefs.setString('tolii_user_last_name', _state.lastName);
      await prefs.setString('tolii_user_username', _state.username);
      await prefs.setString('tolii_user_email', _state.email);
      await prefs.setString('tolii_user_phone', _state.phoneNumber);
      await prefs.setString('tolii_user_city', _state.selectedCity);
      if (_state.gender != null) await prefs.setString('tolii_user_gender', _state.gender!);
      if (_state.profileImagePath != null) await prefs.setString('tolii_user_profile_image', _state.profileImagePath!);
    } catch (e) {
      debugPrint('Error updating SharedPreferences cache: $e');
    }

    notifyListeners();
    return true;
  }

  void updateAvatar(String? avatarUrl) {
    _state.avatarUrl = avatarUrl;
    notifyListeners();
  }

  void updateProfileImagePath(String? path) {
    _state.profileImagePath = path;
    notifyListeners();
  }

  Future<bool> createProfile() async {
    if (_state.firstName.trim().isEmpty) {
      _state.usernameError = 'Please enter your first name';
      notifyListeners();
      return false;
    }

    _state.isLoading = true;
    notifyListeners();

    final success = await saveProfile(
      firstName: _state.firstName,
      lastName: _state.lastName,
      gender: _state.gender,
      profileImagePath: _state.profileImagePath,
    );

    _state.isLoading = false;
    notifyListeners();
    return success;
  }

  void clearAuthError() {
    if (_state.authError != null) {
      _state.authError = null;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _state.isLoading = true;
    _state.authError = null;
    notifyListeners();

    try {
      // 1. Open Native Google Account Picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled account selection
        _state.isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Fetch auth tokens from Google account
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create Firebase auth credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Check if user is currently signed in with Phone OTP (Account Linking case)
      final currentUser = _auth.currentUser;
      UserCredential userCredential;
      if (currentUser != null && currentUser.phoneNumber != null && currentUser.phoneNumber!.isNotEmpty) {
        try {
          userCredential = await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (linkEx) {
          if (linkEx.code == 'credential-already-in-use' || linkEx.code == 'provider-already-linked') {
            userCredential = await _auth.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;

      if (user != null) {
        _state.isGoogleSignedIn = true;
        _state.authMode = 'google';
        _state.googleEmail = user.email;
        _state.googleDisplayName = user.displayName;
        _state.googlePhotoUrl = user.photoURL;

        if (user.email != null && user.email!.isNotEmpty) {
          _state.email = user.email!;
        }

        if (user.displayName != null && user.displayName!.isNotEmpty) {
          final parts = user.displayName!.trim().split(RegExp(r'\s+'));
          _state.firstName = parts.first;
          if (parts.length > 1) {
            _state.lastName = parts.sublist(1).join(' ');
          }
        }

        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          _state.avatarUrl = user.photoURL;
        }

        // Check Firestore as Source of Truth for existing user profile
        final remoteProfile = await _userRepository.getUserProfile(user.uid);
        if (remoteProfile != null) {
          _state.firstName = remoteProfile.firstName;
          _state.lastName = remoteProfile.lastName;
          _state.username = remoteProfile.username;
          _state.email = remoteProfile.email.isNotEmpty ? remoteProfile.email : (user.email ?? '');
          _state.phoneNumber = remoteProfile.phoneNumber.isNotEmpty ? remoteProfile.phoneNumber : (user.phoneNumber ?? '');
          _state.selectedCity = remoteProfile.selectedCity;
          _state.gender = remoteProfile.gender;
          _state.avatarUrl = remoteProfile.photoUrl ?? user.photoURL;
          _state.selectedInterests = List<String>.from(remoteProfile.interests);
          _state.isProfileComplete = remoteProfile.isProfileComplete;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('tolii_is_profile_complete', remoteProfile.isProfileComplete);
        } else {
          // BRAND NEW USER: Zero pre-selected interests & clean location/username
          _state.isProfileComplete = false;
          _state.selectedInterests = [];
          _state.username = '';
          _state.checkedUsername = null;
          _state.usernameValidationStatus = UsernameValidationStatus.idle;
          _state.selectedCity = '';
          _state.areaLocality = '';
          _state.pincode = '';
          _state.landmark = '';
          _state.locationSummary = '';
          _state.isLocationDetected = false;

          if (user.displayName != null && user.displayName!.isNotEmpty) {
            final parts = user.displayName!.trim().split(RegExp(r'\s+'));
            _state.firstName = parts.first;
            if (parts.length > 1) {
              _state.lastName = parts.sublist(1).join(' ');
            }
          }
        }

        _state.isLoading = false;
        if (!_state.isProfileComplete) {
          _state.currentStep = 3;
        }
        notifyListeners();
        return true;
      } else {
        _state.authError = 'Failed to retrieve Firebase user details.';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _state.authError = 'An account already exists with a different sign-in method.';
      } else if (e.code == 'credential-already-in-use') {
        _state.authError = 'This Google account is already linked to another user.';
      } else if (e.code == 'network-request-failed') {
        _state.authError = 'Network connection error. Please try again.';
      } else {
        _state.authError = e.message ?? 'Authentication failed: ${e.code}';
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('10') || message.contains('DEVELOPER_ERROR')) {
        _state.authError = 'Google Sign-In configuration issue. Ensure SHA-1 fingerprint is added in Firebase Console.';
      } else if (!message.contains('canceled') && !message.contains('cancelled')) {
        _state.authError = 'Google Sign-In error: $e';
      }
    }

    _state.isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error during signOut: $e');
    }
    _state.isGoogleSignedIn = false;
    _state.isProfileComplete = false;
    _state.firstName = '';
    _state.lastName = '';
    _state.username = '';
    _state.isUsernameAvailable = false;
    _state.usernameValidationStatus = UsernameValidationStatus.idle;
    _state.checkedUsername = null;
    _state.email = '';
    _state.phoneNumber = '';
    _state.avatarUrl = null;
    _state.profileImagePath = null;
    _state.selectedInterests = [];
    _state.selectedCity = '';
    _state.areaLocality = '';
    _state.pincode = '';
    _state.landmark = '';
    _state.locationSummary = '';
    _state.isLocationDetected = false;
    _state.currentStep = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _usernameDebounceTimer?.cancel();
    super.dispose();
  }
}
