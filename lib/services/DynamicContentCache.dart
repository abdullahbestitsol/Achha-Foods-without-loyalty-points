import 'package:flutter/foundation.dart';
import './DynamicAppData.dart';

class DynamicContentCache extends ChangeNotifier {
  static DynamicContentCache? _instance;

  static DynamicContentCache get instance {
    _instance ??= DynamicContentCache._internal();
    return _instance!;
  }

  DynamicContentCache._internal(); // Private constructor

  static DynamicAppData? cachedData;
  DynamicAppData? get data => cachedData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _hasLoaded = false; // Track if data has been loaded

  // Add a flag to track if we're in a build phase
  bool _isInBuildPhase = false;

  // Safe notify method that checks if we're in build phase
  void _safeNotifyListeners() {
    if (!_isInBuildPhase) {
      notifyListeners();
    }
  }

  // Method to mark when build phase starts/ends
  void setBuildPhase(bool inBuildPhase) {
    _isInBuildPhase = inBuildPhase;
  }

  Future<void> loadDynamicData() async {
    // If already loaded, don't load again
    if (_hasLoaded) {
      debugPrint("✅ Dynamic data already loaded. Skipping fetch.");
      return;
    }

    if (_isLoading) return;

    _isLoading = true;
    _safeNotifyListeners();
    debugPrint("⏳ CACHE STATUS: Starting dynamic data fetch...");

    try {
      final fetchedData = await ApiService().fetchAllDynamicData();
      cachedData = fetchedData;
      _hasLoaded = true; // Mark as loaded

      debugPrint("✅ CACHE STATUS: Data fetched and stored successfully!");
      debugPrint("--- DynamicAppData Contents ---");
      debugPrint("🛒 navigationBarHome: ${fetchedData.navigationBarHome}");
      debugPrint("🛒 navigationBarStore: ${fetchedData.navigationBarStore}");
      debugPrint("🛒 navigationBarMyAccount: ${fetchedData.navigationBarMyAccount}");
      debugPrint("🛒 navigationBarBack: ${fetchedData.navigationBarBack}");
      debugPrint("🏷️ homeFeaturedProducts: ${fetchedData.homeFeaturedProducts}");
      debugPrint("🏷️ homeHotDeals: ${fetchedData.homeHotDeals}");
      debugPrint("🏷️ shopTitle: ${fetchedData.shopTitle}");
      debugPrint("🏷️ shopPopularCategories: ${fetchedData.shopPopularCategories}");
      debugPrint("🖼️ Single Image URL: ${fetchedData.singleImage}");
      debugPrint("🖼️ Shop Image URL: ${fetchedData.shopImageUrl}");
      debugPrint("📞 Contact Number: ${fetchedData.contactDetailsNumber}");
      debugPrint("🤝 Refer Title: ${fetchedData.referAFriendTitle}");
      debugPrint("🌟 Loyalty Title: ${fetchedData.loyaltyPointsTitle}");
      debugPrint("--- End DynamicAppData Contents ---");

    } catch (e) {
      debugPrint("❌ CACHE ERROR: Error fetching and caching dynamic content: $e");
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // 🔄 Force refresh cache (bypasses _hasLoaded check)
  Future<void> refreshDynamicData() async {
    _isLoading = true;
    _safeNotifyListeners();
    debugPrint("🔄 CACHE STATUS: Force refreshing dynamic data...");

    try {
      // Clear the existing cache to ensure fresh data
      cachedData = null;
      _hasLoaded = false;

      final fetchedData = await ApiService().fetchAllDynamicData();
      cachedData = fetchedData;
      _hasLoaded = true;

      debugPrint("✅ CACHE STATUS: Data force refreshed successfully!");
      debugPrint("--- Refreshed DynamicAppData Contents ---");
      debugPrint("🛒 navigationBarHome: ${fetchedData.navigationBarHome}");
      debugPrint("🛒 navigationBarStore: ${fetchedData.navigationBarStore}");
      debugPrint("🛒 navigationBarMyAccount: ${fetchedData.navigationBarMyAccount}");
      debugPrint("📝 Account First Name: ${fetchedData.accountDetails_firstname}");
      debugPrint("📝 Account Last Name: ${fetchedData.accountDetails_lastname}");
      debugPrint("--- End Refreshed Contents ---");

    } catch (e) {
      debugPrint("❌ CACHE ERROR: Error force refreshing dynamic content: $e");
      // Re-throw the error so calling code knows it failed
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Clear cache when app closes (optional)
  void clearCache() {
    cachedData = null;
    _hasLoaded = false;
    _isLoading = false;
    debugPrint("🧹 Cache cleared");
  }

  // All getter methods remain the same...
  String? getFloatingBackgoundColor() => cachedData?.floatingBackgroundColor;
  String? getSingleImage() => cachedData?.singleImage;
  String? getContactUsEmail() => cachedData?.contactDetailsEmail;
  String? getContactUsTitle() => cachedData?.contactDetailsTitle;
  String? getContactUsSubtitle() => cachedData?.contactDetailsSubtitle;
  String? getContactUsNumber() => cachedData?.contactDetailsNumber;
  String? getContactUsAddress() => cachedData?.contactDetailsAddress;
  String? getContactUsTextButton() => cachedData?.contactDetailsTextButton;
  String? getAppbarImage() => cachedData?.appBarImageUrl;
  String? getAppbarIcon() => cachedData?.appBarIcon;
  String? getAccountDetailsText() => cachedData?.accountDetails_text;
  String? getAccountPersonalInformation() => cachedData?.accountDetails_personal_information;
  String? getAccountFirstName() => cachedData?.accountDetails_firstname;
  String? getAccountLastName() => cachedData?.accountDetails_lastname;
  String? getAccountEmail() => cachedData?.accountDetails_email;
  String? getAccountPhoneNumber() => cachedData?.accountDetails_phone_number;
  String? getAccountSavedShippingAddresses() => cachedData?.accountDetails_saved_shipping_addresses;
  String? getAccountChangePasswordTitle() => cachedData?.accountDetails_change_password_title;
  String? getAccountCurrentPassword() => cachedData?.accountDetails_current_password;
  String? getAccountNewPassword() => cachedData?.accountDetails_new_password;
  String? getAccountConfirmNewPassword() => cachedData?.accountDetails_confirm_new_password;
  String? getAccountUpdateButtonText() => cachedData?.accountDetails_update_button_text;
  String? getNavigationBarHome() => cachedData?.navigationBarHome;
  String? getNavigationBarMyAccount() => cachedData?.navigationBarMyAccount;
  String? getNavigationBarStore() => cachedData?.navigationBarStore;
  String? getNavigationBarBack() => cachedData?.navigationBarBack;
  String? getNavigationBarHomeIcon() => cachedData?.navigationBarHomeIcon;
  String? getNavigationBarStoreIcon() => cachedData?.navigationBarStoreIcon;
  String? getNavigationBarMyAccountIcon() => cachedData?.navigationBarMyAccountIcon;
  String? getNavigationBarBackIcon() => cachedData?.navigationBarBackIcon;
  String? getFeaturedProductsTitle() => cachedData?.homeFeaturedProducts;
  String? getHotDealsTitle() => cachedData?.homeHotDeals;
  String? getPopularCollectionsTitle() => cachedData?.homePopularCollections;
  String? getShopTitle() => cachedData?.shopTitle;
  String? getShopPopularCategories() => cachedData?.shopPopularCategories;

  String? getReferAFriendTitle() => cachedData?.referAFriendTitle;
  String? getReferAFriendSubtitle() => cachedData?.referAFriendSubtitle;
  String? getReferAFriendBodyTitle() => cachedData?.referAFriendBodyTitle;
  String? getReferAFriendBodySubtitle() => cachedData?.referAFriendBodySubtitle;
  String? getLoyaltyPointsTitle() => cachedData?.loyaltyPointsTitle;
  String? getLoyaltyPointsSubtitle() => cachedData?.loyaltyPointsSubtitle;
  String? getLoyaltyPointsBodyTitle() => cachedData?.loyaltyPointsBodyTitle;
  String? getLoyaltyPointsBodySubtitle() => cachedData?.loyaltyPointsBodySubtitle;

  List<String> getBannerImages() {
    return cachedData?.bannerItems.map((item) => item.imageUrl).toList() ?? [];
  }

  List<BannerItem> getBannerItems() => cachedData?.bannerItems ?? [];
  String? getShopImage() => cachedData?.shopImageUrl;
  String? getSidebarDrawerText() => cachedData?.sidebarDealsText;
  String? getSidebarDrawerCollectionID() => cachedData?.sidebarDealsCollectionID;
  String? getSidebarHome() => cachedData?.sidebarHome;
  String? getSidebarDeals() => cachedData?.sidebarDeals;
  String? getSidebarStore() => cachedData?.sidebarStore;
  String? getSidebarProductCategories() => cachedData?.sidebarProductCategories;
  String? getSidebarCart() => cachedData?.sidebarCart;
  String? getSidebarMyOrders() => cachedData?.sidebarMyOrders;
  String? getSidebarReferAFriend() => cachedData?.sidebarReferaFriend;
  String? getSidebarLoyaltyPoints() => cachedData?.sidebarLoyaltyPoints;
  String? getSidebarContacts() => cachedData?.sidebarContacts;
  String? getProfileAccountDetails() => cachedData?.profileAccountDetails;
  String? getProfileLogoutText() => cachedData?.profileLogoutText;
  String? getProfileLogoutIcon() => cachedData?.profileLogoutIcon;
  String? getProfileMyOrders() => cachedData?.profileMyOrders;
}