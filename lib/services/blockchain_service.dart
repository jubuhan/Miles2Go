import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web3dart/crypto.dart'; 

class BlockchainService {
  // Alchemy node endpoint - replace with your Alchemy API URL
  static const String _ethereumNodeUrl = 'https://eth-sepolia.g.alchemy.com/v2/tCk57hVUM-QpnVmUQXEZjpz3Dc8Zo9m6';

  // Smart contract address
  static const String _contractAddress = '0xef6136f198102ec9f22d1b761be7a3636050840d';

  // Smart contract ABI
  static final String _contractABI = '''
  [
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "string",
        "name": "rideId",
        "type": "string"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "ipfsCid",
        "type": "string"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "storer",
        "type": "address"
      }
    ],
    "name": "CIDStored",
    "type": "event"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "rideId",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "ipfsCid",
        "type": "string"
      }
    ],
    "name": "storeRideCID",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "rideId",
        "type": "string"
      }
    ],
    "name": "getRideCID",
    "outputs": [
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "rideId",
        "type": "string"
      }
    ],
    "name": "hasCID",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
  ''';

  // Private wallet key (Make sure to store this securely)
  static const String _privateKey = '5bd43a17b3319ddca904299779788b5795876cfbb1a969116942cee1304ff2a4';

  // Web3 client instance
  late web3.Web3Client _web3client;
  late web3.Credentials _credentials;
  late web3.EthereumAddress _contractEthAddress;
  late web3.DeployedContract _contract;
  late web3.ContractFunction _storeRideCIDFunction;
  late web3.ContractFunction _getRideCIDFunction;

  // Initialize the blockchain service
  Future<void> initialize() async {
    _web3client = web3.Web3Client(_ethereumNodeUrl, Client());
    _credentials = web3.EthPrivateKey.fromHex(_privateKey);
    _contractEthAddress = web3.EthereumAddress.fromHex(_contractAddress);
    _contract = web3.DeployedContract(
      web3.ContractAbi.fromJson(_contractABI, 'RideCIDStorage'),
      _contractEthAddress
    );

    _storeRideCIDFunction = _contract.function('storeRideCID');
    _getRideCIDFunction = _contract.function('getRideCID');

    print('Blockchain service initialized with Alchemy');
  }

  // Store a ride CID on the blockchain
  
  Future<String?> storeRideCIDOnBlockchain(String rideId, String ipfsCid) async {
  try {
    print('Storing CID $ipfsCid for ride $rideId on blockchain');

    // Ensure the service is initialized
    await initialize();

    // Fetch gas price dynamically
    //final gasPrice = await _web3client.getGasPrice(); 

    final nonce = await _web3client.getTransactionCount(
      _credentials.address,
       atBlock: web3.BlockNum.pending(),
);

final transaction = await _web3client.sendTransaction(
  _credentials,
  web3.Transaction.callContract(
    contract: _contract,
    function: _storeRideCIDFunction,
    parameters: [rideId, ipfsCid],
    gasPrice: web3.EtherAmount.inWei(BigInt.from(20000000000)), // 20 Gwei
    maxGas: 300000,
    nonce: nonce, // Set correct nonce
  ),
  chainId: 11155111,
);

    print('Transaction sent: $transaction');

    // Wait for the transaction to be mined
    print('Waiting for transaction to be mined...');
    web3.TransactionReceipt? receipt;
    for (int i = 0; i < 20; i++) {
      receipt = await _web3client.getTransactionReceipt(transaction);
      if (receipt != null) break;
      await Future.delayed(Duration(seconds: 5));
    }

    if (receipt == null) {
      print('Transaction not mined after timeout');
      return null;
    }

    print('Transaction mined: ${bytesToHex(receipt.blockHash, include0x: true)}');// Fix block hash output

    // Update Firestore with blockchain transaction info
    await _updateFirestoreWithBlockchainInfo(rideId, ipfsCid, transaction, receipt);

    return transaction;
  } catch (e) {
    print('Error storing CID on blockchain: $e');
    return null;
  }
}


  // Get a ride CID from the blockchain
  Future<String?> getRideCIDFromBlockchain(String rideId) async {
    try {
      await initialize();

      final result = await _web3client.call(
        contract: _contract,
        function: _getRideCIDFunction,
        params: [rideId]
      );

      return result.isNotEmpty ? result[0].toString() : null;
    } catch (e) {
      print('Error getting CID from blockchain: $e');
      return null;
    }
  }

  // Update Firestore with blockchain transaction info
  Future<void> _updateFirestoreWithBlockchainInfo(
    String rideId,
    String ipfsCid,
    String transactionHash,
    web3.TransactionReceipt receipt
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final querySnapshot = await firestore
          .collection('ipfsReferences')
          .where('rideId', isEqualTo: rideId)
          .where('cid', isEqualTo: ipfsCid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No IPFS reference found for ride $rideId with CID $ipfsCid');
        return;
      }

      final docRef = querySnapshot.docs.first.reference;
      await docRef.update({
        'blockchainTxHash': transactionHash,
        'blockchainBlockHash': receipt.blockHash,
        'blockchainBlockNumber': receipt.blockNumber.toString(),
        'blockchainTimestamp': FieldValue.serverTimestamp()
      });

      print('Firestore updated with blockchain transaction info');
    } catch (e) {
      print('Error updating Firestore with blockchain info: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _web3client.dispose();
  }
}