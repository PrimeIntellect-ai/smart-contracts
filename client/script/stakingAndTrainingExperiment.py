"""

Demo of an e2e testing integration script.

Some methods will be best integrated on a
frontend, which will be up to the decision
of Prime Intellect as to how they would
like to integrate those method calls.

"""

import pdb # debug

### 1) INITIALIZE CONNECTION TO LOCAL TESTNET

from web3 import Web3

anvil_url = "http://127.0.0.1:8545"
web3 = Web3(Web3.HTTPProvider(anvil_url))
web3.eth.handleRevert = True

if web3.is_connected():
    print("Connected to Anvil")
else:
    print("Failed to connect to Anvil")

### 2) INITIALIZE CONNECTION TO DEPLOYED CONTRACTS

import json

abi_json_path = "../out/PrimeIntellectToken.sol/PrimeIntellectToken.json"
with open(abi_json_path, "r") as f:
    abi = json.load(f)

token_contract_address = Web3.to_checksum_address(
    "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
)

token_contract = web3.eth.contract(
    address=token_contract_address,
    abi=abi["abi"]
)

abi_json_path = "../out/TrainingManager.sol/TrainingManager.json"
with open(abi_json_path, "r") as f:
    abi = json.load(f)

training_contract_address = Web3.to_checksum_address(
    "0x5fbdb2315678afecb367f032d93f642f64180aa3"
)

training_contract = web3.eth.contract(
    address=training_contract_address,
    abi=abi["abi"]
)

abi_json_path = "../out/StakingManager.sol/StakingManager.json"
with open(abi_json_path, "r") as f:
    abi = json.load(f)

staking_contract_address = Web3.to_checksum_address(
    "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
)

staking_contract = web3.eth.contract(
    address=training_contract_address,
    abi=abi["abi"]
)

print("Initialized connection to contracts")

### 3) INITIALIZE 8 COMPUTE NODES

import os
from dotenv import load_dotenv
load_dotenv()

admin_public_key = os.getenv('MODEL_TRAINER_WALLET_PUBLIC_KEY')
admin_private_key = os.getenv('MODEL_TRAINER_WALLET_PRIVATE_KEY')

chain_id = web3.eth.chain_id

nonce = web3.eth.get_transaction_count(admin_public_key)
call_function = token_contract.functions.grantRole(
    token_contract.functions.getMinterRole.call(),
    staking_contract_address
).build_transaction({
    "chainId": chain_id,
    "from": admin_public_key,
    "nonce": nonce
})
signed_tx = web3.eth.account.sign_transaction(
    call_function,
    private_key=admin_private_key
)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
web3.eth.wait_for_transaction_receipt(send_tx)

nonce = web3.eth.get_transaction_count(admin_public_key)
call_function = training_contract.functions.setStakingManager(
    staking_contract_address
).build_transaction({
    "chainId": chain_id,
    "from": admin_public_key,
    "nonce": nonce
})
signed_tx = web3.eth.account.sign_transaction(
    call_function,
    private_key=admin_private_key
)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
web3.eth.wait_for_transaction_receipt(send_tx)

INITIAL_SUPPLY = int(1000000 * 1e18)
MIN_DEPOSIT = int(10000 * 1e18)
REWARD_RATE = 1

with open('.compute', "r") as f:
    compute_nodes = json.load(f)
compute_nodes = list(compute_nodes.items())
for (index, (public_key, _)) in enumerate(compute_nodes):
    try:
        public_key = Web3.to_checksum_address(public_key)
        nonce = web3.eth.get_transaction_count(admin_public_key)
        call_function = training_contract.functions.whitelistComputeNode(
            public_key,
        ).build_transaction({
            "chainId": chain_id,
            "from": admin_public_key,
            "nonce": nonce
        })
        signed_tx = web3.eth.account.sign_transaction(
            call_function,
            private_key=admin_private_key
        )
        send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        web3.eth.wait_for_transaction_receipt(send_tx)

        nonce = web3.eth.get_transaction_count(admin_public_key)
        call_function = token_contract.functions.approve(
            public_key,
            INITIAL_SUPPLY
        ).build_transaction({
            "chainId": chain_id,
            "from": admin_public_key,
            "nonce": nonce
        })
        signed_tx = web3.eth.account.sign_transaction(
            call_function,
            private_key=admin_private_key
        )
        send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        web3.eth.wait_for_transaction_receipt(send_tx)

        nonce = web3.eth.get_transaction_count(admin_public_key)
        call_function = token_contract.functions.mint(
            public_key,
            INITIAL_SUPPLY
        ).build_transaction({
            "chainId": chain_id,
            "from": admin_public_key,
            "nonce": nonce
        })
        signed_tx = web3.eth.account.sign_transaction(
            call_function,
            private_key=admin_private_key
        )
        send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        web3.eth.wait_for_transaction_receipt(send_tx)
        balance = token_contract.functions.balanceOf(
            public_key
        ).call()
        balance = int(balance / 1e18)

        print("Initialized compute node #{} with {} $PI".format(index + 1, balance))
    except:
        pass

### 4) INITIALIZE TRAINING RUN

for (index, (public_key, private_key)) in enumerate(compute_nodes):

    minStake = int(2 * MIN_DEPOSIT)
    public_key = Web3.to_checksum_address(public_key)
    nonce = web3.eth.get_transaction_count(public_key)
    call_function = token_contract.functions.approve(
        staking_contract_address,
        minStake
    ).build_transaction({
        "chainId": chain_id,
        "from": public_key,
        "nonce": nonce
    })
    signed_tx = web3.eth.account.sign_transaction(
        call_function,
        private_key=private_key
    )
    send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
    web3.eth.wait_for_transaction_receipt(send_tx)

    nonce = web3.eth.get_transaction_count(public_key)
    call_function = staking_contract.functions.stake(MIN_DEPOSIT).build_transaction({"chainId": chain_id,"from": public_key,"nonce": nonce,"gas": 100000})
    signed_tx = web3.eth.account.sign_transaction(call_function,private_key=private_key)
    send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
    response = web3.eth.wait_for_transaction_receipt(send_tx)
    print("Compute node #{} staked {} $PI".format(index + 1, int(MIN_DEPOSIT / 1e18)))
    pdb.set_trace() # Error: reverted with: EvmError: Revert

budget = int(1000 * 1e18)
try:
    nonce = web3.eth.get_transaction_count(admin_public_key)
    call_function = training_contract.functions.registerModel(
        "Test",
        budget
    ).build_transaction({
        "chainId": chain_id,
        "from": admin_public_key,
        "nonce": nonce
    })
    signed_tx = web3.eth.account.sign_transaction(
        call_function,
        private_key=admin_private_key
    )
    send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
    web3.eth.wait_for_transaction_receipt(send_tx)
except:
    pass
trainingRunId = training_contract.functions.getLatestModelId().call()
print("Registered model with training run id #{}".format(trainingRunId))

### 5) TRAINING RUN

for (index, (public_key, private_key)) in enumerate(compute_nodes):
    try:
        public_key = Web3.to_checksum_address(public_key)
        nonce = web3.eth.get_transaction_count(admin_public_key)
        call_function = training_contract.functions.joinTrainingRun(
            public_key,
            "192.168.1." + str(index),
            trainingRunId
        ).build_transaction({
            "chainId": chain_id,
            "from": admin_public_key,
            "nonce": nonce
        })
        signed_tx = web3.eth.account.sign_transaction(
            call_function,
            private_key=admin_private_key
        )
        send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        web3.eth.wait_for_transaction_receipt(send_tx) 
        print("Compute node #{} joined training run #{}".format(index + 1, trainingRunId))
    except Exception as e:
        print(e)
        pass

nonce = web3.eth.get_transaction_count(admin_public_key)
call_function = training_contract.functions.startTrainingRun(
    trainingRunId
).build_transaction({
    "chainId": chain_id,
    "from": admin_public_key,
    "nonce": nonce
})
signed_tx = web3.eth.account.sign_transaction(
    call_function,
    private_key=admin_private_key
)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
web3.eth.wait_for_transaction_receipt(send_tx)

for (index, (public_key, private_key)) in enumerate(compute_nodes):
    try:
        public_key = Web3.to_checksum_address(public_key)
        nonce = web3.eth.get_transaction_count(admin_public_key)
        call_function = training_contract.functions.submitAttestation(
            public_key,
            trainingRunId,
            "attestation"
        ).build_transaction({
            "chainId": chain_id,
            "from": admin_public_key,
            "nonce": nonce
        })
        signed_tx = web3.eth.account.sign_transaction(
            call_function,
            private_key=admin_private_key
        )
        send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        web3.eth.wait_for_transaction_receipt(send_tx)
    except Exception as e:
        print(e)
        pass

nonce = web3.eth.get_transaction_count(admin_public_key)
call_function = training_contract.functions.endTrainingRun(
    trainingRunId
).build_transaction({
    "chainId": chain_id,
    "from": admin_public_key,
    "nonce": nonce
})
signed_tx = web3.eth.account.sign_transaction(
    call_function,
    private_key=admin_private_key
)
send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
web3.eth.wait_for_transaction_receipt(send_tx)

### 6) SLASH / CLAIM

# slash

# claim
## wait 1 week
## claim
## verify
