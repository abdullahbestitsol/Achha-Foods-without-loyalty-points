import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Shoppings/Shop.dart';
import 'package:achhafoods/screens/Refferal/ReferralScreen.dart';
import 'package:achhafoods/screens/LoyalityPoints/LoyaltyPointsScreen.dart';
import '../../utilities/icon_mapping.dart';
import '../Home Screens/homepage.dart';
import '../Profile/MainScreenProfile.dart';
import 'package:achhafoods/services/DynamicContentCache.dart';

class NewNavigationBar extends StatefulWidget {
  const NewNavigationBar({super.key});

  @override
  State<NewNavigationBar> createState() => _NewNavigationBarState();
}

class _NewNavigationBarState extends State<NewNavigationBar> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentIndex = _getCurrentIndex();
  }

  @override
  Widget build(BuildContext context) {
    final dynamicContentCache = Provider.of<DynamicContentCache>(context);
    bool canGoBack = Navigator.canPop(context);

    final destinations = <NavigationDestination>[
      _buildDestination(
        dynamicContentCache,
        dynamicContentCache.getNavigationBarHomeIcon(),
        Icons.home_outlined,
        Icons.home_rounded,
        dynamicContentCache.getNavigationBarHome() ?? 'Home',
      ),
      _buildDestination(
        dynamicContentCache,
        dynamicContentCache.getNavigationBarStoreIcon(),
        Icons.storefront_outlined,
        Icons.storefront_outlined,
        dynamicContentCache.getNavigationBarStore() ?? 'Store',
      ),
      _buildDestination(
        dynamicContentCache,
        dynamicContentCache.getNavigationBarMyAccountIcon(),
        Icons.person_outline,
        Icons.person_rounded,
        dynamicContentCache.getNavigationBarMyAccount() ?? 'My Account',
      ),
    ];

    if (canGoBack) {
      destinations.add(
        NavigationDestination(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.grey[600]),
          selectedIcon: Icon(Icons.arrow_back_ios_new, color: CustomColorTheme.CustomPrimaryAppColor),
          label: dynamicContentCache.getNavigationBarBack() ?? 'Back',
        ),
      );
    }

    int safeIndex = _currentIndex;
    if (safeIndex >= destinations.length) {
      safeIndex = 0;
    }

    return NavigationBar(
      backgroundColor: Colors.white,
      elevation: 8.0,
      shadowColor: Colors.black.withOpacity(0.2),
      height: 70,
      surfaceTintColor: Colors.transparent,
      selectedIndex: safeIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.15),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onDestinationSelected: _onItemTapped,
      destinations: destinations,
      animationDuration: const Duration(milliseconds: 300),
    );
  }

  NavigationDestination _buildDestination(
      DynamicContentCache cache,
      String? iconName,
      IconData defaultUnselected,
      IconData defaultSelected,
      String label,
      ) {
    final unselectedIcon = IconMapping.getIconFromString(iconName ?? '', defaultUnselected);
    final selectedIcon = IconMapping.getIconFromString(iconName ?? '', defaultSelected);

    return NavigationDestination(
      icon: Icon(unselectedIcon, color: Colors.grey[600]),
      selectedIcon: Icon(selectedIcon, color: CustomColorTheme.CustomPrimaryAppColor),
      label: label,
    );
  }

  int _getCurrentIndex() {
    final currentRoute = ModalRoute.of(context);
    if (currentRoute == null) {
      return 0;
    }

    final settings = currentRoute.settings;

    if (settings.arguments is Widget) {
      final widget = settings.arguments as Widget;
      if (widget is HomePage) {
        return 0;
      }
      if (widget is Shop) {
        return 1;
      }
      if (widget is MainScreen) {
        return 2;
      }
    }

    if (settings.name != null) {
      final name = settings.name!.toLowerCase();
      if (name.contains('home')) {
        return 0;
      }
      if (name.contains('shop')) {
        return 1;
      }
      if (name.contains('account') || name.contains('profile')) {
        return 2;
      }
      if (name.contains('referal') || name.contains('loyalty')) {
        return 0;
      }
    }
    return 0;
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index <= 2) {
      setState(() {
        _currentIndex = index;
      });
    }

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomePage(),
            settings: const RouteSettings(name: 'home'),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Shop(),
            settings: const RouteSettings(name: 'shop'),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
            settings: const RouteSettings(name: 'profile'),
          ),
        );
        break;
      case 3:
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ReferralScreen(),
            settings: const RouteSettings(name: 'referral'),
          ),
        );
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoyaltyPointsScreen(),
            settings: const RouteSettings(name: 'loyalty'),
          ),
        );
        break;
    }
  }
}