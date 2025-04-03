const String contractAddress = "0x1c156a74d807219bb5c707f92df66fcb872b9631"; // Replace with actual contract address

const String contractABI = '''
Vicky, [02-04-2025 19:40]
0x1c156a74d807219bb5c707f92df66fcb872b9631

Vicky, [02-04-2025 19:49]
[
  {
    "inputs": [],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
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
        "indexed": true,
        "internalType": "address",
        "name": "passenger",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "rider",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "PaymentMade",
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
        "internalType": "address payable",
        "name": "rider",
        "type": "address"
      }
    ],
    "name": "payRide",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "stateMutability": "payable",
    "type": "receive"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "rideId",
        "type": "string"
      }
    ],
    "name": "isRidePaid",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      }
    ],
    "name": "paidRides",
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
