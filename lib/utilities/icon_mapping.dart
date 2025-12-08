import 'package:flutter/material.dart';

/// A static utility class to map string names (from API) to Flutter IconData objects.
class IconMapping {
  // A comprehensive map containing common icon names and their corresponding IconData.
  static const Map<String, IconData> iconMap = {
    // --- SHOPPING/COMMERCE ICONS (Prioritized) ---
    'shopping_cart': Icons.shopping_cart,
    'cart': Icons.shopping_cart,
    'shopping_cart_outlined': Icons.shopping_cart_outlined,
    'shopping_cart_outline': Icons.shopping_cart_outlined,
    'shopping_bag': Icons.shopping_bag,
    'bag': Icons.shopping_bag,
    'shopping_bag_outlined': Icons.shopping_bag_outlined,
    'shopping_basket': Icons.shopping_basket,
    'basket': Icons.shopping_basket,
    'store': Icons.store,
    'shop': Icons.store,
    'local_mall': Icons.local_mall,
    'receipt': Icons.receipt,
    'payments': Icons.payments,
    'credit_card': Icons.credit_card,
    'attach_money': Icons.attach_money,
    'label': Icons.label,
    'redeem': Icons.redeem,
    'inventory': Icons.inventory,
    'trolley': Icons.shopping_cart,
    'local_offer': Icons.local_offer,
    'loyalty': Icons.loyalty,
    'card_giftcard': Icons.card_giftcard,
    'discount': Icons.discount,
    'price_change': Icons.price_change,
    'point_of_sale': Icons.point_of_sale,
    'qr_code': Icons.qr_code,
    'barcode': Icons.qr_code_2,

    // --- COMMON NAVIGATION/UI ICONS ---
    'home': Icons.home,
    'search': Icons.search,
    'menu': Icons.menu,
    'settings': Icons.settings,
    'person': Icons.person,
    'account_circle': Icons.account_circle,
    'favorite': Icons.favorite,
    'star': Icons.star,
    'notifications': Icons.notifications,
    'mail': Icons.mail,
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'close': Icons.close,
    'delete': Icons.delete,
    'edit': Icons.edit,
    'add': Icons.add,
    'remove': Icons.remove,
    'info': Icons.info,
    'help': Icons.help,
    'location_on': Icons.location_on,
    'visibility': Icons.visibility,
    'more_vert': Icons.more_vert,
    'more_horiz': Icons.more_horiz,
    'expand_more': Icons.expand_more,
    'expand_less': Icons.expand_less,
    'chevron_left': Icons.chevron_left,
    'chevron_right': Icons.chevron_right,
    'refresh': Icons.refresh,
    'download': Icons.download,
    'upload': Icons.upload,
    'share': Icons.share,

    // --- OUTLINED VERSIONS ---
    'home_outlined': Icons.home_outlined,
    'home_outline': Icons.home_outlined,
    'search_outlined': Icons.search_outlined,
    'search_outline': Icons.search_outlined,
    'person_outlined': Icons.person_outlined,
    'person_outline': Icons.person_outlined,
    'favorite_border': Icons.favorite_border,
    'favorite_outline': Icons.favorite_border,
    'notifications_none': Icons.notifications_none,
    'notifications_outline': Icons.notifications_none,
    'delete_outline': Icons.delete_outline,
    'delete_outlined': Icons.delete_outline,
    'star_border': Icons.star_border,
    'star_outline': Icons.star_border,
    'mail_outline': Icons.mail_outline,
    'location_on_outlined': Icons.location_on_outlined,

    // --- FILLED VERSIONS ---
    'shopping_cart_rounded': Icons.shopping_cart_rounded,
    'shopping_cart_sharp': Icons.shopping_cart_sharp,
    'home_filled': Icons.home,
    'favorite_filled': Icons.favorite,
    'star_filled': Icons.star,

    // --- COMMUNICATION ICONS ---
    'call': Icons.call,
    'phone': Icons.phone,
    'message': Icons.message,
    'chat': Icons.chat,
    'chat_bubble': Icons.chat_bubble,
    'comment': Icons.comment,
    'email': Icons.email,
    'contact_mail': Icons.contact_mail,
    'contact_phone': Icons.contact_phone,
    'forum': Icons.forum,
    'support': Icons.support_agent,

    // --- CONTENT ICONS ---
    'create': Icons.create,
    'post_add': Icons.post_add,
    'draft': Icons.drafts,
    'archive': Icons.archive,
    'unarchive': Icons.unarchive,
    'link': Icons.link,
    'attachment': Icons.attachment,
    'cloud': Icons.cloud,
    'cloud_upload': Icons.cloud_upload,
    'cloud_download': Icons.cloud_download,
    'folder': Icons.folder,
    'folder_open': Icons.folder_open,
    'description': Icons.description,
    'article': Icons.article,
    'newspaper': Icons.newspaper,

    // --- ACTION ICONS ---
    'save': Icons.save,
    'bookmark': Icons.bookmark,
    'bookmark_border': Icons.bookmark_border,
    'thumb_up': Icons.thumb_up,
    'thumb_down': Icons.thumb_down,
    'flag': Icons.flag,
    'report': Icons.report,
    'block': Icons.block,
    'build': Icons.build,
    'code': Icons.code,
    'bug_report': Icons.bug_report,
    'lock': Icons.lock,
    'lock_open': Icons.lock_open,
    'vpn_key': Icons.vpn_key,
    'visibility_off_action': Icons.visibility_off, // Renamed key to remove duplicate
    'filter': Icons.filter,
    'sort': Icons.sort,
    'tune': Icons.tune,
    'adjust': Icons.adjust,

    // --- TRANSPORTATION ICONS ---
    'directions_car': Icons.directions_car,
    'flight': Icons.flight,
    'train': Icons.train,
    'directions_bus': Icons.directions_bus,
    'motorcycle': Icons.motorcycle,
    'bike': Icons.pedal_bike,
    'directions_walk': Icons.directions_walk,
    'directions_run': Icons.directions_run,
    'navigation': Icons.navigation,
    'map': Icons.map,
    'location_pin': Icons.location_pin,
    'my_location': Icons.my_location,
    'compass': Icons.explore,

    // --- DEVICE ICONS ---
    'smartphone': Icons.smartphone,
    'phone_iphone': Icons.phone_iphone,
    'phone_android': Icons.phone_android,
    'computer': Icons.computer,
    'laptop': Icons.laptop,
    'tablet': Icons.tablet,
    'watch': Icons.watch,
    'headphones': Icons.headphones,
    'speaker': Icons.speaker,
    'tv': Icons.tv,
    'camera': Icons.camera,
    'camera_alt': Icons.camera_alt,
    'memory': Icons.memory,

    // --- SOCIAL & PEOPLE ICONS ---
    'group': Icons.group,
    'people': Icons.people,
    'person_add': Icons.person_add,
    'person_remove': Icons.person_remove,
    'supervisor_account': Icons.supervisor_account,
    'emoji_people': Icons.emoji_people,
    'mood': Icons.mood,
    'mood_bad': Icons.mood_bad,
    'sentiment_satisfied': Icons.sentiment_satisfied,
    'sentiment_dissatisfied': Icons.sentiment_dissatisfied,
    'celebration': Icons.celebration,
    'cake': Icons.cake,
    'sports_esports': Icons.sports_esports,

    // --- FOOD & RESTAURANT ICONS ---
    'restaurant': Icons.restaurant,
    'local_dining': Icons.local_dining,
    'fastfood': Icons.fastfood,
    'local_cafe': Icons.local_cafe,
    'local_bar': Icons.local_bar,
    'wine_bar': Icons.wine_bar,
    'kitchen': Icons.kitchen,
    'set_meal': Icons.set_meal,
    'icecream': Icons.icecream,
    'bakery': Icons.bakery_dining,

    // --- HEALTH & MEDICAL ICONS ---
    'medical_services': Icons.medical_services,
    'local_hospital': Icons.local_hospital,
    'health_and_safety': Icons.health_and_safety,
    'fitness_center': Icons.fitness_center,
    'spa': Icons.spa,
    'self_improvement': Icons.self_improvement,

    // --- EDUCATION ICONS ---
    'school': Icons.school,
    'book': Icons.book,
    'library_books': Icons.library_books,
    'menu_book': Icons.menu_book,
    'history_edu': Icons.history_edu,
    'science': Icons.science,
    'calculate': Icons.calculate,
    'psychology': Icons.psychology,

    // --- BUSINESS & FINANCE ICONS ---
    'business': Icons.business,
    'work': Icons.work,
    'apartment': Icons.apartment,
    'corporate_fare': Icons.corporate_fare,
    'trending_up': Icons.trending_up,
    'trending_down': Icons.trending_down,
    'analytics': Icons.analytics,
    'bar_chart': Icons.bar_chart,
    'pie_chart': Icons.pie_chart,
    'account_balance': Icons.account_balance,
    'savings': Icons.savings,
    'receipt_long': Icons.receipt_long,

    // --- WEATHER & NATURE ICONS ---
    'wb_sunny': Icons.wb_sunny,
    'cloudy': Icons.cloudy_snowing,
    'rainy': Icons.cloudy_snowing,
    'ac_unit': Icons.ac_unit,
    'whatshot': Icons.whatshot,
    'water_drop': Icons.water_drop,
    'air': Icons.air,
    'forest': Icons.forest,
    'park': Icons.park,
    'nature': Icons.nature,
    'pets': Icons.pets,

    // --- TIME & DATE ICONS ---
    'access_time': Icons.access_time,
    'schedule': Icons.schedule,
    'today': Icons.today,
    'event': Icons.event,
    'calendar_today': Icons.calendar_today,
    'date_range': Icons.date_range,
    'timer': Icons.timer,
    'alarm': Icons.alarm,
    'watch_later': Icons.watch_later,

    // --- SECURITY & PRIVACY ICONS ---
    'security': Icons.security,
    'privacy_tip': Icons.privacy_tip,
    'admin_panel_settings': Icons.admin_panel_settings,
    'verified_user': Icons.verified_user,
    'gpp_good': Icons.gpp_good,
    'gpp_bad': Icons.gpp_bad,

    // --- ACCESSIBILITY ICONS ---
    'accessibility': Icons.accessibility,
    'accessible': Icons.accessible,
    'hearing': Icons.hearing,
    'visibility_off_acc': Icons.visibility_off, // Renamed key to remove duplicate
    'volume_up': Icons.volume_up,
    'volume_off': Icons.volume_off,

    // --- HOUSEHOLD ICONS ---
    'home_repair_service': Icons.home_repair_service,
    'cleaning_services': Icons.cleaning_services,
    'electric_bolt': Icons.electric_bolt,
    'plumbing': Icons.plumbing,
    'yard': Icons.yard,
    'balcony': Icons.balcony,
    'bathtub': Icons.bathtub,
    'bed': Icons.bed,
    'chair': Icons.chair,
    'coffee': Icons.coffee,
    'dining': Icons.dining,
    'light': Icons.light,
    'wash': Icons.wash,

    // --- HOLIDAY & SEASONAL ICONS ---
    'christmas': Icons.ac_unit, // Using snowflake as Christmas
    'holiday_village': Icons.holiday_village,
    'nights_stay': Icons.nights_stay,
    'beach_access': Icons.beach_access,
    'umbrella': Icons.beach_access,

    // --- TECHNOLOGY & DEVELOPMENT ICONS ---
    'developer_mode': Icons.developer_mode,
    'device_hub': Icons.device_hub,
    'router': Icons.router,
    'storage': Icons.storage,
    'usb': Icons.usb,
    'bluetooth': Icons.bluetooth,
    'wifi': Icons.wifi,
    'signal_cellular_alt': Icons.signal_cellular_alt,
    'battery_full': Icons.battery_full,
    'power': Icons.power,

    // --- ENTERTAINMENT ICONS ---
    'movie': Icons.movie,
    'theaters': Icons.theaters,
    'live_tv': Icons.live_tv,
    'sports': Icons.sports,
    'music_note': Icons.music_note,
    'library_music': Icons.library_music,
    'gamepad': Icons.gamepad,
    'casino': Icons.casino,
    'photo_library': Icons.photo_library,
    'video_library': Icons.video_library,

    // --- TRANSPORT & LOGISTICS ICONS ---
    'local_shipping': Icons.local_shipping,
    'flight_takeoff': Icons.flight_takeoff,
    'flight_land': Icons.flight_land,
    'package': Icons.inventory_2,
    'delivery_dining': Icons.delivery_dining,
    'two_wheeler': Icons.two_wheeler,
    'electric_scooter': Icons.electric_scooter,
    'electric_car': Icons.electric_car,
    'gas_station': Icons.local_gas_station,

    // --- ADDITIONAL COMMON ICONS ---
    'warning': Icons.warning,
    'error': Icons.error,
    'error_outline': Icons.error_outline,
    'check_circle': Icons.check_circle,
    'cancel': Icons.cancel,
    'highlight_off': Icons.highlight_off,
    'task_alt': Icons.task_alt,
    'done': Icons.done,
    'done_all': Icons.done_all,
    'remove_circle': Icons.remove_circle,
    'add_circle': Icons.add_circle,
    'play_arrow': Icons.play_arrow,
    'pause': Icons.pause,
    'stop': Icons.stop,
    'replay': Icons.replay,
    'skip_next': Icons.skip_next,
    'skip_previous': Icons.skip_previous,
    'volume_mute': Icons.volume_mute,
    'shuffle': Icons.shuffle,
    'repeat': Icons.repeat,
    'speed': Icons.speed,
    'gradient': Icons.gradient,
    'palette': Icons.palette,
    'brush': Icons.brush,
    'format_paint': Icons.format_paint,
    'tag': Icons.tag,
    'tags': Icons.local_offer,
  };

  /// Converts a string icon name into a Flutter IconData object.
  /// If the name is not found, it returns the provided fallback icon.
  static IconData getIconFromString(String iconName, IconData fallback) {
    if (iconName.isEmpty) return fallback;

    final key = iconName.toLowerCase().trim();
    print("Looking up icon for key: '$key'"); // Debug

    // Look up the icon in the map. Returns IconData or fallback.
    final iconData = iconMap[key];

    if (iconData == null) {
      print("Icon not found for key: '$key'. Using fallback: $fallback");
    } else {
      print("Icon found: $iconData for key: '$key'");
    }

    return iconData ?? fallback;
  }

  /// Utility method to print all available icons in the map (for debugging)
  static void printAvailableIcons() {
    print('Available icons in mapping:');
    iconMap.forEach((key, value) {
      print('$key -> $value');
    });
  }

  /// Get all available icon keys (for debugging or UI purposes)
  static List<String> getAvailableIconKeys() {
    return iconMap.keys.toList();
  }

  /// Check if an icon exists in the mapping
  static bool hasIcon(String iconName) {
    if (iconName.isEmpty) return false;
    final key = iconName.toLowerCase().trim();
    return iconMap.containsKey(key);
  }
}