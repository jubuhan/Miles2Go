import 'package:flutter/material.dart';
import '../screens/service_selection_screen.dart';

class WalletSelectionPage extends StatefulWidget {
  const WalletSelectionPage({Key? key}) : super(key: key);

  @override
  State<WalletSelectionPage> createState() => _WalletSelectionPageState();
}

class _WalletSelectionPageState extends State<WalletSelectionPage> {
  bool _isLoading = false;

  Future<bool> _checkKYCStatus(String walletType) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<bool> _connectWallet(String walletType) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<void> _handleWalletSelection(String walletType) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isKYCApproved = await _checkKYCStatus(walletType);

      if (!isKYCApproved) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC verification required for this wallet')),
        );
        return;
      }

      final isConnected = await _connectWallet(walletType);

      if (!mounted) return;

      if (isConnected) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ServiceSelectionScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect wallet')),
        );
      }
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
                        height: 350, // Increased height for better visibility
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
                        _buildWalletButton(
                          onTap: () => _handleWalletSelection('binance'),
                          imagePath: 'assets/images/binance_logo.png',
                          title: 'BINANCE',
                          color: Colors.orange,
                        ),
                        const Divider(
                          color: Colors.black54,
                          height: 40,
                        ),
                        _buildWalletButton(
                          onTap: () => _handleWalletSelection('bybit'),
                          imagePath: 'assets/images/bybit.png',
                          title: 'BYBIT',
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
          // Show the image if provided
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
