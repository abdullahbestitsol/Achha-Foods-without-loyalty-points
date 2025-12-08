import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:achhafoods/screens/Consts/conts.dart';
const String apiUrl = localurl;

// Function to launch URL (requires url_launcher package)
Future<void> launchUrlString(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    debugPrint('Invalid URL: $url');
    return;
  }

  // Ensure you are using canLaunchUrl and launchUrl as shown
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // This is the line printing 'Could not launch...'
    debugPrint('Could not launch $url');
  }
}

// -------------------------------------------------------------------------
// NEW BANNER ITEM MODEL
// -------------------------------------------------------------------------
class BannerItem {
  final String imageUrl;
  final String? moveUrl;

  BannerItem({required this.imageUrl, this.moveUrl});
}

// -------------------------------------------------------------------------
// DYNAMIC APP DATA MODEL (UPDATED)
// -------------------------------------------------------------------------
class DynamicAppData {
  final List<BannerItem> bannerItems;
  final String? floatingBackgroundColor;
  final String? shopImageUrl;
  final String? appBarImageUrl;
  final String? appBarIcon;
  final String? singleImage;
  final String? accountDetails_text;
  final String? accountDetails_personal_information;
  final String? accountDetails_firstname;
  final String? accountDetails_lastname;
  final String? accountDetails_email;
  final String? accountDetails_phone_number;
  final String? accountDetails_saved_shipping_addresses;
  final String? accountDetails_change_password_title;
  final String? accountDetails_current_password;
  final String? accountDetails_new_password;
  final String? accountDetails_confirm_new_password;
  final String? accountDetails_update_button_text;
  final String? navigationBarHome;
  final String? navigationBarStore;
  final String? navigationBarMyAccount;
  final String? navigationBarBack;
  final String? navigationBarHomeIcon;
  final String? navigationBarStoreIcon;
  final String? navigationBarMyAccountIcon;
  final String? navigationBarBackIcon;
  final String? contactDetailsNumber;
  final String? contactDetailsEmail;
  final String? contactDetailsAddress;
  final String? contactDetailsTitle;
  final String? contactDetailsSubtitle;
  final String? contactDetailsTextButton;
  final String? homeFeaturedProducts;
  final String? homeHotDeals;
  final String? homePopularCollections;
  final String? shopTitle;
  final String? shopPopularCategories;
  final String? sidebarHome;
  final String? sidebarStore;
  final String? sidebarProductCategories;
  final String? sidebarCart;
  final String? sidebarDeals;
  final String? sidebarDealsText;
  final String? sidebarDealsCollectionID;
  final String? sidebarMyOrders;
  final String? sidebarReferaFriend;
  final String? sidebarLoyaltyPoints;
  final String? sidebarContacts;
  final String? profileAccountDetails;
  final String? profileLogoutText;
  final String? profileLogoutIcon;
  final String? profileMyOrders;

  // 🚨 NEW FIELDS FROM UPLOADED IMAGES 🚨
  final String? referAFriendTitle;
  final String? referAFriendSubtitle;
  final String? referAFriendBodyTitle;
  final String? referAFriendBodySubtitle;
  final String? loyaltyPointsTitle;
  final String? loyaltyPointsSubtitle;
  final String? loyaltyPointsBodyTitle;
  final String? loyaltyPointsBodySubtitle;
  // 🚨 END NEW FIELDS 🚨

  DynamicAppData({
    required this.bannerItems,
    this.floatingBackgroundColor,
    this.shopImageUrl,
    this.accountDetails_change_password_title,
    this.accountDetails_confirm_new_password,
    this.accountDetails_current_password,
    this.accountDetails_email,
    this.accountDetails_firstname,
    this.accountDetails_lastname,
    this.accountDetails_new_password,
    this.accountDetails_personal_information,
    this.accountDetails_phone_number,
    this.accountDetails_saved_shipping_addresses,
    this.accountDetails_text,
    this.accountDetails_update_button_text,
    this.navigationBarHome,
    this.appBarImageUrl,
    this.appBarIcon,
    this.navigationBarStore,
    this.navigationBarBack,
    this.navigationBarMyAccount,
    this.navigationBarHomeIcon,
    this.navigationBarStoreIcon,
    this.navigationBarMyAccountIcon,
    this.navigationBarBackIcon,
    this.contactDetailsAddress,
    this.contactDetailsEmail,
    this.contactDetailsNumber,
    this.contactDetailsTitle,
    this.contactDetailsTextButton,
    this.contactDetailsSubtitle,
    this.singleImage,
    this.homeFeaturedProducts,
    this.homeHotDeals,
    this.homePopularCollections,
    this.shopTitle,
    this.shopPopularCategories,
    this.sidebarHome,
    this.sidebarStore,
    this.sidebarDeals,
    this.sidebarProductCategories,
    this.sidebarCart,
    this.sidebarDealsText,
    this.sidebarDealsCollectionID,
    this.sidebarMyOrders,
    this.sidebarReferaFriend,
    this.sidebarLoyaltyPoints,
    this.sidebarContacts,
    this.profileAccountDetails,
    this.profileLogoutText,
    this.profileLogoutIcon,
    this.profileMyOrders,
    // 🚨 NEW FIELDS IN CONSTRUCTOR 🚨
    this.referAFriendTitle,
    this.referAFriendSubtitle,
    this.referAFriendBodyTitle,
    this.referAFriendBodySubtitle,
    this.loyaltyPointsTitle,
    this.loyaltyPointsSubtitle,
    this.loyaltyPointsBodyTitle,
    this.loyaltyPointsBodySubtitle,
    // 🚨 END NEW FIELDS 🚨
  });

  factory DynamicAppData.fromJson(Map<String, dynamic> json) {
    // debugPrint('DynamicAppData: Starting data parsing.');

    // CHANGED: Use list of BannerItem objects
    List<BannerItem> orderedItems = [];

    // --- 1. Extract Banner Images (Handles gaps like 1, 2, 4) ---
    const int maxBannersToCheck = 10;

    for (int i = 1; i <= maxBannersToCheck; i++) {
      final key = 'banner_image$i';

      if (json.containsKey(key)) {
        final dynamic item = json[key];

        if (item is Map) {
          final itemData = Map<String, dynamic>.from(item);
          final imagePath = itemData['image_path'] as String?;

          // NEW: Extract move_url
          final moveUrl = itemData['move_url'] as String?;

          if (imagePath != null && imagePath.isNotEmpty) {
            final fullImageUrl = '$apiUrl$imagePath';

            // Add the new BannerItem object
            orderedItems.add(BannerItem(
              imageUrl: fullImageUrl,
              moveUrl: moveUrl,
            ));
          }
        }
      }
    }

    // --- 2. Extract Single Image ---
    String? singleImageUrl;
    final singleImageItem = json['single_image'];
    if (singleImageItem != null && singleImageItem is Map) {
      final singleImageItemMap = Map<String, dynamic>.from(singleImageItem);
      final imagePath = singleImageItemMap['image_path'] as String?;

      if (imagePath != null && imagePath.isNotEmpty) {
        singleImageUrl = '$apiUrl$imagePath';
      }
    }

    // --- 3. Extract Shop Image URL ---
    String? shopImageUrl;
    final shopImageItem = json['Shop Image'];
    if (shopImageItem != null && shopImageItem is Map) {
      final shopImageItemMap = Map<String, dynamic>.from(shopImageItem);
      final imagePath = shopImageItemMap['image_path'] as String?;

      if (imagePath != null && imagePath.isNotEmpty) {
        shopImageUrl = '$apiUrl$imagePath';
      }
    }

    // --- 4. Extract App Bar Image URL ---
    String? appBarImageUrl;
    final appBarImageItem = json['appbar_image'];
    if (appBarImageItem != null && appBarImageItem is Map) {
      final singleImageItemMap = Map<String, dynamic>.from(appBarImageItem);
      final imagePath = singleImageItemMap['image_path'] as String?;

      if (imagePath != null && imagePath.isNotEmpty) {
        appBarImageUrl = '$apiUrl$imagePath';
      }
    }


    // --- 5. Extract Individual Text Fields ---
    String? getTextValue(String key) {
      if (json.containsKey(key) && json[key] is Map) {
        final itemMap = Map<String, dynamic>.from(json[key] as Map);
        return itemMap['value'] as String?;
      }
      return null;
    }

    final floatingBackgroundColor = getTextValue('floating_icon_color');
    final accountdetailsText = getTextValue('account_details_text');
    final accountdetailsPersonalInformation = getTextValue('account_details_personal_information');
    final accountdetailsFirstname = getTextValue('account_details_firstname');
    final accountdetailsLastname = getTextValue('account_details_lastname');
    final accountdetailsEmail = getTextValue('account_details_email');
    final accountdetailsPhoneNumber = getTextValue('account_details_phone_number');
    final accountdetailsSavedShippingAddresses = getTextValue('account_details_saved_shipping_addresses');
    final accountdetailsChangePasswordTitle = getTextValue('account_details_change_password_title');
    final accountdetailsCurrentPassword = getTextValue('account_details_current_password');
    final accountdetailsNewPassword = getTextValue('account_details_new_password');
    final accountdetailsConfirmNewPassword = getTextValue('account_details_confirm_new_password');
    final accountdetailsUpdateButtonText = getTextValue('account_details_update_button_text');

    final appBarIcon = getTextValue('appbar_icon');

    final navigationBarHome = getTextValue('navigation_bar_home');
    final navigationBarStore = getTextValue('navigation_bar_store');
    final navigationBarBack = getTextValue('navigation_bar_back');
    final navigationBarMyAccount = getTextValue('navigation_bar_my_account');
    final navigationBarHomeIcon = getTextValue('navigation_bar_home_icon');
    final navigationBarStoreIcon = getTextValue('navigation_bar_store_icon');
    final navigationBarMyAccountIcon = getTextValue('navigation_bar_my_account_icon');
    final navigationBarBackIcon = getTextValue('navigation_bar_back_icon');
    final contactDetailsNumber = getTextValue('contact_details_number');
    final contactDetailsTextButton = getTextValue('contact_details_text_button');
    final contactDetailsEmail = getTextValue('contact_details_email');
    final contactDetailsAddress = getTextValue('contact_details_address');
    final contactDetailsTitle = getTextValue('contact_details_title');
    final contactDetailsSubtitle = getTextValue('contact_details_subtitle');
    final homeFeaturedProducts = getTextValue('home_featured_products');
    final homeHotDeals = getTextValue('home_hot_deals');
    final homePopularCollections = getTextValue('home_popular_collections');
    final shopTitle = getTextValue('shop_title');
    final shopPopularCategories = getTextValue('shop_popular_shop_categories');
    final sidebarHome = getTextValue('sidebar_home');
    final sidebarStore = getTextValue('sidebar_store');
    final sidebarDeals = getTextValue('sidebar_deals');
    final sidebarDealsText = getTextValue('drawer_deals_text');
    final sidebarDealsCollectionID = getTextValue('drawer_deals_collection_id');
    final sidebarProductCategories = getTextValue('sidebar_product_categories');
    final sidebarCart = getTextValue('sidebar_cart');
    final sidebarMyOrders = getTextValue('sidebar_my_orders');
    final sidebarReferaFriend = getTextValue('sidebar_refer_a_friend');
    final sidebarLoyaltyPoints = getTextValue('sidebar_loyalty_points');
    final sidebarContacts = getTextValue('sidebar_contacts');
    final profileAccountDetails = getTextValue('profile_account_details');
    final profileLogoutText = getTextValue('profile_logout_button_text');
    final profileLogoutIcon = getTextValue('profile_logout_button_icon');
    final profileMyOrders = getTextValue('profile_my_orders');

    // 🚨 NEW TEXT EXTRACTION FROM UPLOADED IMAGES 🚨
    final referAFriendTitle = getTextValue('refer_a_friend_title');
    final referAFriendSubtitle = getTextValue('refer_a_friend_subtitle');
    final referAFriendBodyTitle = getTextValue('refer_a_friend_body_title');
    final referAFriendBodySubtitle = getTextValue('refer_a_friend_body_subtitle');
    final loyaltyPointsTitle = getTextValue('loyalty_points_title');
    final loyaltyPointsSubtitle = getTextValue('loyalty_points_subtitle');
    final loyaltyPointsBodyTitle = getTextValue('loyalty_points_body_title');
    final loyaltyPointsBodySubtitle = getTextValue('loyalty_points_body_subtitle');
    // 🚨 END NEW TEXT EXTRACTION 🚨


    return DynamicAppData(
      floatingBackgroundColor: floatingBackgroundColor,
      bannerItems: orderedItems,
      shopImageUrl: shopImageUrl,
      appBarImageUrl: appBarImageUrl,
      appBarIcon: appBarIcon,
      accountDetails_text: accountdetailsText,
      accountDetails_personal_information: accountdetailsPersonalInformation,
      accountDetails_firstname: accountdetailsFirstname,
      accountDetails_lastname: accountdetailsLastname,
      accountDetails_email: accountdetailsEmail,
      accountDetails_phone_number: accountdetailsPhoneNumber,
      accountDetails_saved_shipping_addresses: accountdetailsSavedShippingAddresses,
      accountDetails_change_password_title: accountdetailsChangePasswordTitle,
      accountDetails_current_password: accountdetailsCurrentPassword,
      accountDetails_new_password: accountdetailsNewPassword,
      accountDetails_confirm_new_password: accountdetailsConfirmNewPassword,
      accountDetails_update_button_text: accountdetailsUpdateButtonText,
      navigationBarHome: navigationBarHome,
      navigationBarStore: navigationBarStore,
      navigationBarBack: navigationBarBack,
      navigationBarMyAccount: navigationBarMyAccount,
      navigationBarHomeIcon: navigationBarHomeIcon,
      navigationBarStoreIcon: navigationBarStoreIcon,
      navigationBarMyAccountIcon: navigationBarMyAccountIcon,
      navigationBarBackIcon: navigationBarBackIcon,
      singleImage: singleImageUrl,
      contactDetailsNumber: contactDetailsNumber,
      contactDetailsEmail: contactDetailsEmail,
      contactDetailsAddress: contactDetailsAddress,
      contactDetailsTextButton: contactDetailsTextButton,
      contactDetailsTitle: contactDetailsTitle,
      contactDetailsSubtitle: contactDetailsSubtitle,
      homeFeaturedProducts: homeFeaturedProducts,
      homeHotDeals: homeHotDeals,
      homePopularCollections: homePopularCollections,
      shopTitle: shopTitle,
      shopPopularCategories: shopPopularCategories,
      sidebarHome: sidebarHome,
      sidebarDeals: sidebarDeals,
      sidebarDealsText: sidebarDealsText,
      sidebarDealsCollectionID: sidebarDealsCollectionID,
      sidebarStore: sidebarStore,
      sidebarProductCategories: sidebarProductCategories,
      sidebarCart: sidebarCart,
      sidebarMyOrders: sidebarMyOrders,
      sidebarReferaFriend: sidebarReferaFriend,
      sidebarLoyaltyPoints: sidebarLoyaltyPoints,
      sidebarContacts: sidebarContacts,
      profileAccountDetails: profileAccountDetails,
      profileLogoutText: profileLogoutText,
      profileLogoutIcon: profileLogoutIcon,
      profileMyOrders: profileMyOrders,
      // 🚨 NEW FIELDS IN RETURN 🚨
      referAFriendTitle: referAFriendTitle,
      referAFriendSubtitle: referAFriendSubtitle,
      referAFriendBodyTitle: referAFriendBodyTitle,
      referAFriendBodySubtitle: referAFriendBodySubtitle,
      loyaltyPointsTitle: loyaltyPointsTitle,
      loyaltyPointsSubtitle: loyaltyPointsSubtitle,
      loyaltyPointsBodyTitle: loyaltyPointsBodyTitle,
      loyaltyPointsBodySubtitle: loyaltyPointsBodySubtitle,
      // 🚨 END NEW FIELDS 🚨
    );
  }
}

// -------------------------------------------------------------------------
// API SERVICE (UNCHANGED, but included for completeness)
// -------------------------------------------------------------------------
class ApiService {
  Future<DynamicAppData> fetchAllDynamicData() async {
    final uri = Uri.parse('$apiUrl/api/content');
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> responseList = json.decode(response.body);
        final Map<String, dynamic> dynamicContentMap = {};

        for (var item in responseList) {
          if (item is Map) {
            final Map<String, dynamic> typedItem = Map<String, dynamic>.from(item);

            if (typedItem.containsKey('key')) {
              final key = typedItem['key'] as String;
              dynamicContentMap[key] = typedItem;
            }
          }
        }
        if (dynamicContentMap.isNotEmpty) {
          return DynamicAppData.fromJson(dynamicContentMap);
        } else {
          throw Exception('Failed to load dynamic content. Received empty list or list with no keys.');
        }

      } else {
        throw Exception('Failed to load dynamic content. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network/Decoding Error: $e');
      rethrow;
    }
  }
}