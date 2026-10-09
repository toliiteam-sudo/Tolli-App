enum UsernameValidationStatus {
  idle,
  invalid,
  checking,
  available,
  taken,
  error,
}

class AuthModel {
  String authMode; // 'phone' or 'email'
  String email;
  String phoneNumber;
  String phoneCountryCode;
  String rawPhoneNumber;
  String otp;
  bool isWhatsappOptedIn;
  int currentStep; // 1 to 5

  // Location fields
  double? latitude;
  double? longitude;
  String selectedState;
  String selectedCity;
  String areaLocality;
  String streetAddress;
  String pincode;
  String landmark;
  String locationSummary;
  bool isLocationDetected;

  // Interests
  List<String> selectedInterests;

  // Profile fields
  String firstName;
  String lastName;
  String username;
  bool isUsernameAvailable;
  UsernameValidationStatus usernameValidationStatus;
  String? checkedUsername;
  String? avatarUrl;
  String? profileImagePath;
  String? gender;
  bool isProfileComplete;

  // Google Auth fields
  String? googleDisplayName;
  String? googleEmail;
  String? googlePhotoUrl;
  bool isGoogleSignedIn;

  String? get photoUrl => avatarUrl ?? googlePhotoUrl;

  // Error & loading states
  String? phoneError;
  String? emailError;
  String? otpError;
  String? pincodeError;
  String? usernameError;
  String? authError;
  bool isLoading;

  AuthModel({
    this.authMode = 'phone',
    this.email = '',
    this.phoneNumber = '',
    this.phoneCountryCode = '+91',
    this.rawPhoneNumber = '',
    this.otp = '',
    this.isWhatsappOptedIn = true,
    this.currentStep = 1,
    this.selectedState = '',
    this.selectedCity = '',
    this.areaLocality = '',
    this.streetAddress = '',
    this.pincode = '',
    this.landmark = '',
    this.locationSummary = '',
    this.isLocationDetected = false,
    List<String>? selectedInterests,
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.isUsernameAvailable = false,
    this.usernameValidationStatus = UsernameValidationStatus.idle,
    this.avatarUrl,
    this.profileImagePath,
    this.gender,
    this.isProfileComplete = false,
    this.googleDisplayName,
    this.googleEmail,
    this.googlePhotoUrl,
    this.isGoogleSignedIn = false,
    this.phoneError,
    this.emailError,
    this.otpError,
    this.pincodeError,
    this.usernameError,
    this.authError,
    this.isLoading = false,
  }) : selectedInterests = selectedInterests ?? [];

  String get displayName {
    final full = '$firstName $lastName'.trim();
    if (full.isNotEmpty) return full;
    if (googleDisplayName != null && googleDisplayName!.trim().isNotEmpty) {
      return googleDisplayName!.trim();
    }
    if (username.isNotEmpty) return username;
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String? get effectiveAvatarUrl {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl;
    if (googlePhotoUrl != null && googlePhotoUrl!.isNotEmpty) return googlePhotoUrl;
    return null;
  }

  String get fullPhoneNumber =>
      '$phoneCountryCode ${rawPhoneNumber.replaceAll(' ', '')}'.trim();

  AuthModel copyWith({
    String? authMode,
    String? email,
    String? phoneNumber,
    String? phoneCountryCode,
    String? rawPhoneNumber,
    String? otp,
    bool? isWhatsappOptedIn,
    int? currentStep,
    String? selectedState,
    String? selectedCity,
    String? areaLocality,
    String? streetAddress,
    String? pincode,
    String? landmark,
    String? locationSummary,
    bool? isLocationDetected,
    List<String>? selectedInterests,
    String? firstName,
    String? lastName,
    String? username,
    bool? isUsernameAvailable,
    String? avatarUrl,
    String? gender,
    String? phoneError,
    String? emailError,
    String? otpError,
    String? pincodeError,
    String? usernameError,
    bool? isLoading,
  }) {
    return AuthModel(
      authMode: authMode ?? this.authMode,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCountryCode: phoneCountryCode ?? this.phoneCountryCode,
      rawPhoneNumber: rawPhoneNumber ?? this.rawPhoneNumber,
      otp: otp ?? this.otp,
      isWhatsappOptedIn: isWhatsappOptedIn ?? this.isWhatsappOptedIn,
      currentStep: currentStep ?? this.currentStep,
      selectedState: selectedState ?? this.selectedState,
      selectedCity: selectedCity ?? this.selectedCity,
      areaLocality: areaLocality ?? this.areaLocality,
      streetAddress: streetAddress ?? this.streetAddress,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      locationSummary: locationSummary ?? this.locationSummary,
      isLocationDetected: isLocationDetected ?? this.isLocationDetected,
      selectedInterests: selectedInterests ?? List.from(this.selectedInterests),
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      isUsernameAvailable: isUsernameAvailable ?? this.isUsernameAvailable,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      phoneError: phoneError,
      emailError: emailError,
      otpError: otpError,
      pincodeError: pincodeError,
      usernameError: usernameError,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
