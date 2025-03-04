import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miles2go/login/otp_success.dart';

class OtpLicensePage extends StatefulWidget {
  const OtpLicensePage({Key? key}) : super(key: key);

  @override
  _OtpVerificationPageState createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpLicensePage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );
  bool _isResendEnabled = false;
  int _timer = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
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

   void _startTimer() {
    setState(() {
      _isResendEnabled = false;
      _timer = 60;
    });
    Future.delayed(Duration(seconds: 1), _decrementTimer);
  }

    void _resendOTP() {
    if (_isResendEnabled) {
      _startTimer();
      // Add resend OTP logic here
    }
  }

  @override
  Widget build(BuildContext context) {
    return 
        Scaffold(
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
        body: Container(
          
          // decoration: BoxDecoration(
          //   gradient: LinearGradient(
          //     begin: Alignment.topCenter,
          //     end: Alignment.bottomCenter,
          //     colors: [
          //       Colors.blue.shade900,
          //       Colors.teal.shade800,
          //     ],
          //   ),
          // ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Otp has been sent to your registered mail id',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => SizedBox(
                              width: 60,
                              height: 60,
                              child: TextFormField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                onChanged: (value) => _onOtpChanged(value, index),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(1),
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Handle OTP verification
                              // Navigator.of(context).push(
                              //   MaterialPageRoute(
                              //   builder: (context) => const OtpSuccessPage(),
                              //   ),
                              //   );
                              // String otp = _controllers
                              //     .map((controller) => controller.text)
                              //     .join();
                              // Verify OTP logic here
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'VERIFY OTP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        )
                      ],
                    ),
                  ),
                ),
                // Background illustration can be added here using Image.asset
              ],
            ),
          ),
        ),
    
    );
  }
}