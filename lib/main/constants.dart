/// App-wide constants used throughout the application
class AppConstants {
  /// The entitlement ID for premium features
  static const String entitlementID = "Premium";
  
  /// Gets the footer text with current year
  static String get footerText => "© ${DateTime.now().year} Arthaksh. All rights reserved.";
  
  /// Purchase agreement text for premium subscriptions
  static const String purchaseAgreementText = 
      'By purchasing a subscription, you agree to our Terms of Service and Privacy Policy. '
      'Payment will be charged to your account upon confirmation of purchase. '
      'Subscriptions automatically renew unless auto-renew is turned off at least 24-hours before the end of the current period. '
      'Your account will be charged for renewal within 24 hours prior to the end of the current period.';
}
