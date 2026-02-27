/// API Configuration
/// Update the baseUrl to match your backend server

class ApiConfig {
  // Development - Running locally
  static const String devBaseUrl = 'http://localhost:5000/api';

  // Production - Replace with your production server URL
  static const String prodBaseUrl = 'https://api.your-domain.com/api';

  // Android emulator - Use this if running on Android emulator
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:5000/api';

  // Get the appropriate base URL based on the build environment
  static String get baseUrl {
    // Change this to 'prod' when deploying to production
    const String environment = 'dev';

    switch (environment) {
      case 'prod':
        return prodBaseUrl;
      case 'android':
        return androidEmulatorBaseUrl;
      case 'dev':
      default:
        return devBaseUrl;
    }
  }

  /// Connection timeout in seconds
  static const int connectionTimeout = 30;

  /// Receive timeout in seconds
  static const int receiveTimeout = 30;
}
