import 'dart:convert';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

class WalletConnectService {
  Web3App? _web3app;
  SessionData? _sessionData;

  Future<void> initWalletConnect() async {
    _web3app = await Web3App.createInstance(
      projectId: '2e933723437ddb31f1723a48fded47b6', // Replace with your actual WalletConnect Project ID
      metadata: const PairingMetadata(
        name: 'Flutter WalletConnect',
        description: 'Flutter WalletConnect Dapp Example',
        url: 'https://walletconnect.com/',
        icons: ['https://walletconnect.com/walletconnect-logo.png'],
      ),
    );
  }

  Future<void> connectWallet(Function(String) logUpdate) async {
    if (_web3app == null) {
      await initWalletConnect();
    }

    final connectResponse = await _web3app!.connect(
      optionalNamespaces: {
        'eip155': const RequiredNamespace(
          chains: ['eip155:1'],
          methods: ["personal_sign", "eth_sendTransaction"],
          events: ["chainChanged", "accountsChanged"],
        ),
      },
    );

    final uri = connectResponse.uri;
    if (uri == null) {
      throw Exception('Uri not found');
    }

    // Directly open MetaMask
    final url = 'metamask://wc?uri=${Uri.encodeComponent('$uri')}';
    await launchUrlString(url, mode: LaunchMode.externalApplication);

    _sessionData = await connectResponse.session.future;
    logUpdate('✅ Connected to MetaMask');
  }

  Future<void> requestAuthWithWallet(Function(String) logUpdate) async {
    if (_web3app == null || _sessionData == null) {
      await connectWallet(logUpdate);
    }

    logUpdate('🔄 Requesting authentication...');

    final authResponse = await _web3app!.requestAuth(
      pairingTopic: _sessionData!.pairingTopic,
      params: AuthRequestParams(
        chainId: 'eip155:1',
        domain: 'walletconnect.org',
        aud: 'https://walletconnect.org/login',
      ),
    );

    final authCompletion = await authResponse.completer.future;
    logUpdate(authCompletion.error == null
        ? '✅ Authentication Successful'
        : '❌ Auth Error: ${authCompletion.error}');
  }
}