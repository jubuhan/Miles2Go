import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:miles2go/screens/bottom_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:miles2go/screens/customersupport.dart';
import 'package:miles2go/screens/editprofile.dart';
import 'package:miles2go/screens/notification.dart';
import 'package:miles2go/screens/privacyandpolicy.dart';
import 'package:miles2go/screens/service_selection_screen.dart';
import 'package:miles2go/screens/termsandcondition.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({Key? key}) : super(key: key);

  @override
  _ProfileSettingsPageState createState() => _ProfileSettingsPageState();
  
  // Static method to verify if emergency contact exists
  static Future<bool> verifyEmergencyContactExists() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final emergencyContact = userData['emergencyContact'];
      
      return emergencyContact != null && emergencyContact.isNotEmpty;
    } catch (e) {
      print('Error verifying emergency contact: $e');
      return false;
    }
  }
}


class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  int _selectedIndex = 2; // Set to 2 to highlight 'Rides' tab by default
  String _userName = "Loading...";
  String _userEmail = "Loading...";

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

@override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? "No Email";
      });

      // Fetch additional user details from Firestore (if stored)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userName = userDoc['userName'] ?? "User";
          //_userPhotoUrl = userDoc['photoUrl'] ?? "";
        });
      }
    }
  }

  void _logout() {
    // Implement logout functionality here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut(); // Sign out user
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login', // Replace with your actual login route name
              (route) => false,
            );
          },
          child: const Text(
            "Logout",
            style: TextStyle(color: Colors.red),
          ),
        ),
        ],
      ),
    );
  }


  void _navigateToServiceSelection() {
    // Navigate to the service selection (wallet selection) page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServiceSelectionScreen(),
      ),
    );
  }
  
  void _showEmergencyContactDialog() async {
    // Get current emergency contact if it exists
    String currentEmergencyContact = '';
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          currentEmergencyContact = userData['emergencyContact'] ?? '';
        }
      }
    } catch (e) {
      print('Error getting emergency contact: $e');
    }
    
    final TextEditingController controller = TextEditingController(text: currentEmergencyContact);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This number will be called in case of an emergency during your rides.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _saveEmergencyContact(controller.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid phone number'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEmergencyContact(String number) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'emergencyContact': number,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contact saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving emergency contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save emergency contact'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          onPressed: _navigateToServiceSelection,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16.0),
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
                      children:  [
                        Text(
                          _userName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _userEmail,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                        onTap: () {
                          // Navigate to edit profile page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfilePage(
                                initialName: _userName,
                                initialEmail: _userEmail,
                              ),
                            ),
                          ).then((_) {
                            // Refresh user details when coming back from edit profile
                            _fetchUserDetails();
                          });
                        },
                        child: Icon(Icons.edit, color: Colors.black87),
                      ),
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

                  _buildSettingsItem(Icons.notifications_active, "Notification",
                      "Explore the notifications"),
                  _buildSettingsItem(Icons.list_alt, "Terms & Conditions",
                      "know our terms and conditions"),
                  _buildSettingsItem(
                      Icons.share, "Refer & Earn", "In-progress and completed orders"),
                  _buildSettingsItem(Icons.privacy_tip, "Privacy policy",
                      "know our privacy policy"),
                  _buildSettingsItem(Icons.headphones, "Customer support",
                      "connect us for any issue"),
                  _buildSettingsItem(Icons.emergency, "Emergency Contact",
                      "Set up your emergency contact for safety"),
                ],
              ),
            ),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "LOGOUT",
                    style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
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
      onTap: () {
        if (title == "Notification") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotificationsPage()),
          );
        } else if (title == "Terms & Conditions") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
          );
        } else if (title == "Privacy policy") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Privacyandpolicy()),
          );
        } else if (title == "Customer support") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerSupportPage()),
          );
        } else if (title == "Emergency Contact") {
          _showEmergencyContactDialog();
        }
      },
    );
  }
}