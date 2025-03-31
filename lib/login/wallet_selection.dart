import 'package:flutter/material.dart';
import 'package:miles2go/screens/service_selection_screen.dart';
import 'package:miles2go/services/walletconnect.dart'; // Ensure this file has connectWallet()

class WalletSelectionPage extends StatefulWidget {
  const WalletSelectionPage({Key? key}) : super(key: key);

  @override
  State<WalletSelectionPage> createState() => _WalletSelectionPageState();
}

class _WalletSelectionPageState extends State<WalletSelectionPage> {
  bool _isLoading = false;
  final WalletConnectService _walletConnectService = WalletConnectService(); // ✅ Use WalletConnectService

  Future<void> _handleMetaMaskSelection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _walletConnectService.initWalletConnect(); // ✅ Ensure initialization
      await _walletConnectService.connectWallet((message) {
        debugPrint(message);
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ServiceSelectionScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/wallet_image.jpg',
                        height: 350,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Binance Button (Unchanged)
                        _buildWalletButton(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Binance not available yet')),
                            );
                          },
                          imagePath: 'assets/images/binance_logo.png',
                          title: 'BINANCE',
                          color: Colors.orange,
                        ),
                        const Divider(
                          color: Colors.black54,
                          height: 40,
                        ),
                        // MetaMask Button (Replaces Bybit)
                        _buildWalletButton(
                          onTap: _handleMetaMaskSelection,
                          imagePath: 'assets/images/metamask.png', // Replace with MetaMask logo
                          title: 'METAMASK',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletButton({
    required VoidCallback onTap,
    required String imagePath,
    required String title,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: color, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.black54,
            size: 20,
          ),
        ],
      ),
    );
  }
}
