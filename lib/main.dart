import 'package:achhafoods/services/shopify_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemChrome
import 'package:provider/provider.dart';
import 'package:achhafoods/screens/CartScreen/Cart.dart';
import 'package:achhafoods/screens/Home%20Screens/homepage.dart';
import 'package:achhafoods/screens/WishListScreen/WishList.dart';
import 'package:achhafoods/services/DynamicContentCache.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // IMPORT ONESIGNAL

// Global Key to allow navigation from OneSignal event
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // This handles the "Edge-to-Edge" appearance at the Dart level
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Makes status bar transparent
    statusBarIconBrightness: Brightness.dark, // Dark icons (time, battery) for white background
    systemNavigationBarColor: Colors.white, // Matches your app theme
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // --- START ONESIGNAL SETUP ---
  // 1. Initialize with your App ID
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("95a86ca2-d6db-49cd-a022-c9884c7f3ad1");

  // 2. Request Permission
  OneSignal.Notifications.requestPermission(true);

  // 3. Handle Notification Clicks
  OneSignal.Notifications.addClickListener((event) {
    var data = event.notification.additionalData;
    if (data != null && data.containsKey('product_id')) {
      String productId = data['product_id'].toString();
      // Clean the ID (remove "gid://shopify/Product/" etc if present)
      productId = productId.replaceAll(RegExp(r'\D'), '');

      print("User clicked notification for Product ID: $productId");

      // Navigate to HomePage or specific screen using the navigatorKey
      // You can customize this later to go to a specific ProductDetail screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  });
  // --- END ONESIGNAL SETUP ---

  await ShopifyService.initToken();
  // Load all data once when app starts
  await Cart.loadCartItems();
  await Wishlist.loadWishlist();

  // Load dynamic content once at app startup
  final dynamicCache = DynamicContentCache.instance;
  await dynamicCache.loadDynamicData();

  runApp(MyApp(dynamicCache: dynamicCache));
}

class MyApp extends StatelessWidget {
  final DynamicContentCache dynamicCache;

  const MyApp({super.key, required this.dynamicCache});

  @override
  Widget build(BuildContext context) {
    return MultiProvider( // Changed to MultiProvider in case you add more services later
      providers: [
        ChangeNotifierProvider.value(value: dynamicCache),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // Added navigatorKey here for OneSignal redirection
        debugShowCheckedModeBanner: false,
        title: 'Achha emart store',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
          useMaterial3: true,
          // Ensures scaffold background is white across the app
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for 2 seconds, then navigate to the home page
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) { // Added safety check
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/emart.png',
              width: 150,
              height: 150,
              // Added error builder to prevent splash screen crash if image is missing
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.store, size: 100, color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// import 'package:achhafoods/services/shopify_service.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Added for SystemChrome
// import 'package:provider/provider.dart';
// import 'package:achhafoods/screens/CartScreen/Cart.dart';
// import 'package:achhafoods/screens/Home%20Screens/homepage.dart';
// import 'package:achhafoods/screens/WishListScreen/WishList.dart';
// import 'package:achhafoods/services/DynamicContentCache.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // This handles the "Edge-to-Edge" appearance at the Dart level
//   SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//     statusBarColor: Colors.transparent, // Makes status bar transparent
//     statusBarIconBrightness: Brightness.dark, // Dark icons (time, battery) for white background
//     systemNavigationBarColor: Colors.white, // Matches your app theme
//     systemNavigationBarIconBrightness: Brightness.dark,
//   ));
//
//   await ShopifyService.initToken();
//   // Load all data once when app starts
//   await Cart.loadCartItems();
//   await Wishlist.loadWishlist();
//
//   // Load dynamic content once at app startup
//   final dynamicCache = DynamicContentCache.instance;
//   await dynamicCache.loadDynamicData();
//
//   runApp(MyApp(dynamicCache: dynamicCache));
// }
//
// class MyApp extends StatelessWidget {
//   final DynamicContentCache dynamicCache;
//
//   const MyApp({super.key, required this.dynamicCache});
//
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider( // Changed to MultiProvider in case you add more services later
//       providers: [
//         ChangeNotifierProvider.value(value: dynamicCache),
//       ],
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         title: 'Achha emart store',
//         theme: ThemeData(
//           colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
//           useMaterial3: true,
//           // Ensures scaffold background is white across the app
//           scaffoldBackgroundColor: Colors.white,
//         ),
//         home: const SplashScreen(),
//       ),
//     );
//   }
// }
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   _SplashScreenState createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Wait for 2 seconds, then navigate to the home page
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) { // Added safety check
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const HomePage()),
//         );
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Image.asset(
//               'assets/images/emart.png',
//               width: 150,
//               height: 150,
//               // Added error builder to prevent splash screen crash if image is missing
//               errorBuilder: (context, error, stackTrace) =>
//               const Icon(Icons.store, size: 100, color: Colors.grey),
//             ),
//             const SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }
// }


// import 'package:achhafoods/services/shopify_service.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:achhafoods/screens/CartScreen/Cart.dart';
// import 'package:achhafoods/screens/Home%20Screens/homepage.dart';
// import 'package:achhafoods/screens/WishListScreen/WishList.dart';
// import 'package:achhafoods/services/DynamicContentCache.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   await ShopifyService.initToken();
//   // Load all data once when app starts
//   await Cart.loadCartItems();
//   await Wishlist.loadWishlist();
//
//   // Load dynamic content once at app startup
//   final dynamicCache = DynamicContentCache.instance;
//   await dynamicCache.loadDynamicData();
//
//   runApp(MyApp(dynamicCache: dynamicCache));
// }
//
// class MyApp extends StatelessWidget {
//   final DynamicContentCache dynamicCache;
//
//   const MyApp({super.key, required this.dynamicCache});
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider.value(
//       value: dynamicCache,
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         title: 'Achha emart store',
//         theme: ThemeData(
//           colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
//           useMaterial3: true,
//         ),
//         home: const SplashScreen(),
//       ),
//     );
//   }
// }
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   _SplashScreenState createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Wait for 2 seconds, then navigate to the home page
//     Future.delayed(const Duration(seconds: 2), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const HomePage()),
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Image.asset(
//               'assets/images/emart.png',
//               width: 150,
//               height: 150,
//             ),
//             const SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }
// }