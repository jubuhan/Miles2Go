import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:miles2go/main.dart'; // Import for SignUpPage

class VerificationInstructionsPage extends StatefulWidget {
  final String email;
  final String password;
  
  const VerificationInstructionsPage({
    Key? key,
    required this.email,
    required this.password,
  }) : super(key: key);

  @override
  _VerificationInstructionsPageState createState() =>
      _VerificationInstructionsPageState();
}

class _VerificationInstructionsPageState extends State<VerificationInstructionsPage> {
  bool _isVerified = false;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  Timer? _timer;
  Timer? _verificationTimer;
  int _timeLeft = 60;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timeLeft = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _startVerificationCheck() {
    // Check every 3 seconds if the email has been verified
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    if (_isVerified) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Make sure we're signed in
      User? user = _auth.currentUser;
      
      if (user == null || user.email != widget.email) {
        // Sign in with credentials if not already signed in
        await _auth.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
        user = _auth.currentUser;
      }
      
      if (user != null) {
        // Reload user data to get fresh verification status
        await user.reload();
        user = _auth.currentUser; // Get updated user
        
        if (user != null && user.emailVerified) {
          // Email is verified
          _verificationTimer?.cancel();
          
          setState(() {
            _isVerified = true;
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to signup page with verified email
          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            // IMPORTANT: Keep the user signed in to reuse the account
            // Log so we can confirm user is still signed in
            log('User verification complete. User ID: ${user.uid}, Email: ${user.email}');
            
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => SignUpPage(verifiedEmail: widget.email),
              ),
              (route) => false, // Remove all previous routes
            );
          }
        }
      }
    } catch (e) {
      log('Error checking verification: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _manualCheck() async {
    _checkEmailVerified();
  }

  Future<void> _resendVerificationEmail() async {
    if (_timeLeft > 0) {
      return; // Still in cooldown
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      User? user = _auth.currentUser;
      
      if (user == null) {
        // Sign in to get the user
        await _auth.signInWithEmailAndPassword(
          email: widget.email, 
          password: widget.password
        );
        user = _auth.currentUser;
      }
      
      if (user != null) {
        // Send verification email
        await user.sendEmailVerification();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent. Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Restart timer
        _startTimer();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error resending email: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_read,
                  color: Colors.blue,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ve sent a verification email to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your inbox and click the verification link to complete your registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _manualCheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'I\'VE VERIFIED MY EMAIL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_timeLeft > 0 || _isResending) 
                      ? null 
                      : _resendVerificationEmail,
                  child: _isResending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _timeLeft > 0
                              ? 'Resend Email (${_timeLeft}s)'
                              : 'Resend Verification Email',
                          style: TextStyle(
                            color: _timeLeft > 0
                                ? Colors.grey
                                : Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Didn\'t receive the email? Check your spam folder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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