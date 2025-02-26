import 'package:flutter/material.dart';

// Create a base layout that includes the bottom navigation
class Miles2GoBaseLayout extends StatefulWidget {
  final Widget body;
  final String title;
  final bool showBackButton;
  
  const Miles2GoBaseLayout({
    Key? key, 
    required this.body, 
    required this.title,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  _Miles2GoBaseLayoutState createState() => _Miles2GoBaseLayoutState();
}

class _Miles2GoBaseLayoutState extends State<Miles2GoBaseLayout> {
  int _selectedIndex = 0;
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      
      // Here you would typically navigate to different screens
      // Example:
      // if (index == 0) {
      //   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
      // } else if (index == 1) {
      //   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => SearchScreen()));
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.blue,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: widget.body,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue.shade900,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.white70,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Example usage in your SignUpPage
class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  // Your controllers and other variables...

  @override
  Widget build(BuildContext context) {
    return Miles2GoBaseLayout(
      title: 'Sign Up',
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.teal.shade800,
            ],
          ),
        ),
        child: SafeArea(
          // Your form content here
          child: Center(
            child: SingleChildScrollView(
              // Rest of your signup form...
            ),
          ),
        ),
      ),
    );
  }
}

// Example usage in your LoginPage
class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Miles2GoBaseLayout(
      title: 'Login',
      body: Container(
        // Your login page content
      ),
    );
  }
}