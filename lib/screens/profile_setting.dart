import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:miles2go/screens/bottom_navigation.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({Key? key}) : super(key: key);

  @override
  _ProfileSettingsPageState createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  int _selectedIndex = 2; // Set to 2 to highlight 'Rides' tab by default
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                //color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(
                      "https://img.freepik.com/free-photo/portrait-handsome-young-man-closeup_176420-15568.jpg?t=st=1741509939~exp=1741513539~hmac=c7ce4ab65de5c1f7addd9517387776391b4da468c131dad0cdfbbb42367f4619&w=1380", // Replace with actual image
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "vivek ps",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "vivekplavila@gmail.com",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.black87),
                ],
              ),
            ),

            // Account Settings List
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Account Settings",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildSettingsItem(Icons.location_on, "My Addresses",
                      "Set shopping delivery address"),
                  _buildSettingsItem(Icons.shopping_cart, "My Cart",
                      "Add, remove products and move to checkout"),
                  _buildSettingsItem(
                      Icons.list_alt, "My Orders", "In-progress and Completed Orders"),
                  _buildSettingsItem(Icons.account_balance, "Bank Account",
                      "Withdraw balance to registered bank account"),
                  _buildSettingsItem(Icons.discount, "My Coupons",
                      "List of all the discounted coupons"),
                  _buildSettingsItem(
                      Icons.notifications, "Notifications", "Set any kind of notification message"),
                  _buildSettingsItem(Icons.lock, "Account Privacy",
                      "Manage data usage and connected accounts"),
                  
                  const SizedBox(height: 20),
                  // const Text(
                  //   "App Settings",
                  //   style: TextStyle(
                  //     fontSize: 18,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.white,
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        title,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.black54, fontSize: 13),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 16),
      onTap: () {},
    );
  }
}