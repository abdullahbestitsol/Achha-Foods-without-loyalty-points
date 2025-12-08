import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:achhafoods/screens/CartScreen/Cart.dart';
import 'package:achhafoods/screens/Home%20Screens/homepage.dart';
import 'package:achhafoods/screens/WishListScreen/WishList.dart';
import 'package:achhafoods/services/DynamicContentCache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return ChangeNotifierProvider.value(
      value: dynamicCache,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Achha emart store',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
          useMaterial3: true,
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
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
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}