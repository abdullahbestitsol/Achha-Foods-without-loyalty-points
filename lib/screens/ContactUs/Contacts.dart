import 'package:achhafoods/services/DynamicContentCache.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Add this import
import 'package:url_launcher/url_launcher.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import '../Consts/CustomFloatingButton.dart';

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  @override
  Widget build(BuildContext context) {
    // Use Provider to get the instance
    final dynamicContentData = Provider.of<DynamicContentCache>(context);

    final List<String> info1 = [
      "${dynamicContentData.getContactUsAddress()}",
      "Mobile: ${dynamicContentData.getContactUsNumber()}"
    ];

    final List<String> titles = ["Address", "Contact"];

    final List<String> info2 = [
      "",
      "E-mail: ${dynamicContentData.getContactUsEmail()}"
    ];

    return Scaffold(
      bottomNavigationBar: const NewNavigationBar(),
      appBar: const CustomAppBar(),
      floatingActionButton: CustomWhatsAppFAB(),
      drawer: const CustomDrawer(),
      body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${dynamicContentData.getContactUsTitle()}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  Text(
                    "${dynamicContentData.getContactUsSubtitle()}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: titles.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titles[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          info1[index],
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (info2[index].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            info2[index],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final whatsappNumber = '${dynamicContentData.getContactUsNumber()}';
                final whatsappUrl = Uri.parse('https://wa.me/$whatsappNumber');

                if (await canLaunchUrl(whatsappUrl)) {
                  await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open WhatsApp')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: Text(
                "${dynamicContentData.getContactUsTextButton()}",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ]
      ),
    );
  }
}