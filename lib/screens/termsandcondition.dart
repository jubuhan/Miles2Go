import 'package:flutter/material.dart';
import 'package:miles2go/screens/bottom_navigation.dart';

class TermsAndConditionsPage extends StatefulWidget {
  const TermsAndConditionsPage({Key? key}) : super(key: key);

  @override
  _TermsAndConditionsPageState createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  int _selectedIndex = 2; // Set to match the current page in bottom navigation

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Terms & Conditions",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Logo and App Name
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  // App Logo
                  Image.asset(
                    'assets/images/terms.jpg', // Update this path to your actual logo
                    //  height: 80,
                    //  width: 180,
                   // color: Colors.amber,
                  ),
                  const SizedBox(height: 12),
                  // App Name
                  const Text(
                    "Miles2Go",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            // Terms and Conditions Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTermsSection(
                    "Lorem ipsum dolor sit amet consectetur adipiscing orci cras amet. Viverra massa amet etd diam a nisiac aliquet felis. Duis sagittis neque hen dreritmaecenas suspendisse scelerisque. Eu est bibendum ornare",
                  ),
                  const SizedBox(height: 16),
                  _buildTermsSection(
                    "Lorem ipsum dolor sit amet consectetur adipiscing orci cras amet. Viverra massa xamet et diam a nisiac aliquet felis. Duis sagittis ne que hendreritmaecenas suspendisse scelerisque. Exaucest bibendum ornare lacinia in. Turpis rutrum conguxe sollicitudin viverra. Suscipit sagittis cursus arcuxgfh kest mattis. Blandit quam vitae id nunc ornare nec morbi. Sapien massa sed lectus a erat in cras dui ut. Id ut bibendum eget ultrices in nunc. Pretium amet adipiscing mattis",
                  ),
                  const SizedBox(height: 16),
                  _buildTermsSection(
                    "Lorem ipsum dolor sit amet consectetur adipiscing orci cras amet. Vivxerra massa amet et diam a nisiac aliquet felis. Duis sagittis neque hendreritmaecenas suspendisse scelerisque. Eu est bibxendums ornare lacinia in. Turpis rutrum congue sollic citudin viverra. Suscipit sagittis cursus arcuxgfh kest mattis. Blaxndit quam vitae id nunc ornare nec morbi. Sapien massa sed lectus a erat in cras dui ut. Id ut bibendum eget ultrices in nunc. Pretium amet adipis cinsadg mattis Lorem ipsum dolor sit amet consectetur uspendisse orci cras amet. Viverra massa amet etx diam a nisiac aliquet felis. Duis sagittis neque",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildTermsSection(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
        height: 1.5,
      ),
    );
  }
}