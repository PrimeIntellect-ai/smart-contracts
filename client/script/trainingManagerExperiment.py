"""

Original integration testing script.

"""

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

contract_address = Web3.to_checksum_address(
    "0x5fbdb2315678afecb367f032d93f642f64180aa3"
)

contract = web3.eth.contract(address=contract_address, abi=abi["abi"])

### 3) TEST THE CONTRACT FUNCTIONS

# register: model trainer
pub_key = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
pri_key = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
chain_id = web3.eth.chain_id
caller = pub_key
nonce = web3.eth.get_transaction_count(caller)
call_function = contract.functions.registerTrainingRun("test", 10).build_transaction(
    {"chainId": chain_id, "from": caller, "nonce": nonce}
)

call_function = contract.functions.registerTrainingRun("test", 10).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
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
call_function = contract.functions.registerComputeNode(
    node_1_pub_key, node_1_ip_address, run_id
).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
signed_tx = web3.eth.account.sign_transaction(
    call_function, private_key=node_1_priv_key
)

call_function = contract.functions.registerComputeNode(node_1_pub_key, node_1_ip_address, run_id).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
signed_tx = web3.eth.account.sign_transaction(call_function, private_key=node_1_priv_key)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
# print(tx_receipt)
run_status = contract.functions.getTrainingRunStatus(run_id).call()
print("Run status ", run_status)  # 0
nodes = contract.functions.getComputeNodesForTrainingRun(run_id).call()
print("Registered nodes ", nodes)
is_valid = contract.functions.isComputeNodeValid(node_1_pub_key).call()
print("Is valid? ", node_1_pub_key, is_valid)  # True
is_valid = contract.functions.isComputeNodeValid(pub_key).call()
print("Is valid? ", node_1_pub_key, is_valid)  # False
print("Run status ", run_status) # 0
nodes = contract.functions.getComputeNodesForTrainingRun(run_id).call()
print("Registered nodes ", nodes)
is_valid = contract.functions.isComputeNodeValid(node_1_pub_key).call()
print("Is valid? ", node_1_pub_key, is_valid) # True
is_valid = contract.functions.isComputeNodeValid(pub_key).call()
print("Is valid? ", node_1_pub_key, is_valid) # False

# start: model trainer
caller = pub_key
nonce = web3.eth.get_transaction_count(caller)
call_function = contract.functions.startTrainingRun(run_id).build_transaction(
    {"chainId": chain_id, "from": caller, "nonce": nonce}
)

call_function = contract.functions.startTrainingRun(run_id).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
signed_tx = web3.eth.account.sign_transaction(call_function, private_key=pri_key)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
# print(tx_receipt)
run_status = contract.functions.getTrainingRunStatus(run_id).call()
print("Run status ", run_status)  # 1

# train: compute node
import os

caller = node_1_pub_key
for i in range(3):
    nonce = web3.eth.get_transaction_count(caller)
    attestation = b"\x00" + os.urandom(4) + b"\x00"
    call_function = contract.functions.submitAttestation(
        node_1_pub_key, run_id, attestation
    ).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
    signed_tx = web3.eth.account.sign_transaction(
        call_function, private_key=node_1_priv_key
    )
    send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
    tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
    # print(tx_receipt)
    attestations = contract.functions.getAttestationsForComputeNode(
        node_1_pub_key
    ).call()
print("Run status ", run_status) # 1

# train: compute node
import os
caller = node_1_pub_key
for i in range(3):
    nonce = web3.eth.get_transaction_count(caller)
    attestation = b"\x00"+os.urandom(4)+b"\x00"
    call_function = contract.functions.submitAttestation(node_1_pub_key, run_id, attestation).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
    signed_tx = web3.eth.account.sign_transaction(call_function, private_key=node_1_priv_key)
    send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
    tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
    # print(tx_receipt)
    attestations = contract.functions.getAttestationsForComputeNode(node_1_pub_key).call()
    print("Attestations ", attestations)

# end: model trainer
caller = pub_key
nonce = web3.eth.get_transaction_count(caller)
call_function = contract.functions.endTrainingRun(run_id).build_transaction(
    {"chainId": chain_id, "from": caller, "nonce": nonce}
)
call_function = contract.functions.endTrainingRun(run_id).build_transaction({"chainId": chain_id, "from": caller, "nonce": nonce})
signed_tx = web3.eth.account.sign_transaction(call_function, private_key=pri_key)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
# print(tx_receipt)
run_status = contract.functions.getTrainingRunStatus(run_id).call()
print("Run status ", run_status)  # 2
print("Run status ", run_status) # 2
# emit

"""

% python -i main.py
Connected to Anvil
Name test
Budget 10
Registered training run  2
Run status  0
Registered nodes  ['0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC']
Is valid?  0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC True
Is valid?  0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC False
Run status  1
Attestations  [b'\x00u{3\xe3\x00']
Attestations  [b'\x00u{3\xe3\x00', b'\x00\xdc\x93\xedE\x00']
Attestations  [b'\x00u{3\xe3\x00', b'\x00\xdc\x93\xedE\x00', b'\x00<E\xf1F\x00']
Run status  2

"""
