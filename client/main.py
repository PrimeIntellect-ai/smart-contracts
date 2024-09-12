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

abi_json_path = "../out/TrainingManager.sol/TrainingManager.json"
with open(abi_json_path, "r") as f:
    abi = json.load(f)

contract_address = Web3.to_checksum_address('0x5fbdb2315678afecb367f032d93f642f64180aa3')

contract = web3.eth.contract(address=contract_address, abi=abi['abi'])

### 3) TEST THE CONTRACT FUNCTIONS

def get_name():
    return contract.functions.name().call()

def get_budget():
    return contract.functions.budget().call()

print("Name", get_name())
print("Budget", get_budget())

"""
% python3 -i main.py
Connected to Anvil
Name PrimeIntellectReward
Symbol PRIME
"""   

# register: model trainer
pub_key = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
pri_key = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
chain_id = web3.eth.chain_id
caller = pub_key
nonce = web3.eth.get_transaction_count(caller)
call_function = contract.functions.registerTrainingRun().build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
signed_tx = web3.eth.account.sign_transaction(call_function, private_key=pri_key)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
# print(tx_receipt)
run_id = contract.functions.registerTrainingRun().call()
print("Registered training run ", run_id)

# register: compute node
node_1_pub_key = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
node_1_priv_key = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
node_1_ip_address = "test_ip_1"
caller = node_1_pub_key
nonce = web3.eth.get_transaction_count(caller)
call_function = contract.functions.registerComputeNode(node_1_pub_key, node_1_ip_address, run_id).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
signed_tx = web3.eth.account.sign_transaction(call_function, private_key=node_1_priv_key)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)

# start: model trainer

# train: compute node

# end: model trainer

# emit (?)
