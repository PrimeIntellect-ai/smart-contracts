from web3 import Web3
import json

### 1) INITIALIZE CONNECTION TO LOCAL TESTNET

anvil_url = "http://127.0.0.1:8545"
web3 = Web3(Web3.HTTPProvider(anvil_url))

if web3.is_connected():
    print("Connected to Anvil")
else:
    print("Failed to connect to Anvil")

### 2) INITIALIZE CONNECTION TO DEPLOYED CONTRACT

abi_json_path = "../out/PrimeToken.sol/PrimeToken.json"
with open(abi_json_path, "r") as f:
    abi = json.load(f)

contract_address = Web3.to_checksum_address('0x5fbdb2315678afecb367f032d93f642f64180aa3')

contract = web3.eth.contract(address=contract_address, abi=abi['abi'])

### 3) TEST THE CONTRACT FUNCTIONS

def get_name():
    return contract.functions.name().call()

def get_symbol():
    return contract.functions.symbol().call()

print("Name", get_name())
print("Symbol", get_symbol())

"""
% python3 -i main.py
Connected to Anvil
Name PrimeIntellectReward
Symbol PRIME
"""   
