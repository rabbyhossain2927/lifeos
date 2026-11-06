/// Things you fill in once. See docs/SETUP-GUIDE.md.
class Config {
  static const appName = 'LifeOS';

  /// Your own sync server: the lifeos-api folder you uploaded to your hosting
  /// (must be https). See docs/SETUP-GUIDE.md, Part 2.
  static const apiBase = 'https://rabbyhossain.com/lifeos-api';

  /// The public GitHub repo. The app reads its latest Release to find updates.
  static const githubOwner = 'rabbyhossain2927';
  static const githubRepo = 'lifeos';

  /// Firebase console > Authentication > Sign-in method > Google >
  /// "Web SDK configuration" > Web client ID. Ends with .apps.googleusercontent.com
  static const googleWebClientId = 'PASTE-WEB-CLIENT-ID.apps.googleusercontent.com';

  /// Your shop's License API (shop admin > Settings > License API).
  static const licenseApi = 'https://shop.rabbyhossain.com/api/license';

  /// The product link (slug) of "LifeOS Pro" in your shop.
  static const licenseProduct = 'lifeos';
  static const buyUrl = 'https://shop.rabbyhossain.com/p/lifeos';

  static const supportEmail = 'shop@rabbyhossain.com';
}
