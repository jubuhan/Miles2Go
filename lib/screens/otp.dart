import 'package:flutter/material.dart';
import 'verify.dart'; // Import the Verify OTP page

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _OtpPageState createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> _otpControllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isResendEnabled = false;
  int _timer = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _isResendEnabled = false;
      _timer = 60;
    });
    Future.delayed(Duration(seconds: 1), _decrementTimer);
  }

  void _decrementTimer() {
    if (_timer > 0) {
      setState(() {
        _timer--;
      });
      Future.delayed(Duration(seconds: 1), _decrementTimer);
    } else {
      setState(() {
        _isResendEnabled = true;
      });
    }
  }

  void _handleVerifyOTP() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VerifyOTPPage()),
    );
  }

  void _resendOTP() {
    if (_isResendEnabled) {
      _startTimer();
      // Add resend OTP logic here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B3B98), Color(0xFF6A89CC)], // Gradient background
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Text(
                  "OTP has been sent to your registered mail ID",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white, // Text color
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    return SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(color: Colors.black, fontSize: 20),
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: Colors.white, // Input field background
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 3) {
                            FocusScope.of(context)
                                .requestFocus(_focusNodes[index + 1]);
                          }
                          if (value.isEmpty && index > 0) {
                            FocusScope.of(context)
                                .requestFocus(_focusNodes[index - 1]);
                          }
                        },
                      ),
                    );
                  }),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleVerifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent, // Button color
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Verify OTP",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                SizedBox(height: 16),
                GestureDetector(
                  onTap: _resendOTP, // Resend OTP logic
                  child: Text(
                    _isResendEnabled
                        ? "Resend OTP"
                        : "Resend OTP in $_timer seconds",
                    style: TextStyle(
                      color: _isResendEnabled
                          ? Colors.lightBlueAccent
                          : Colors.grey, // Disabled color
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
