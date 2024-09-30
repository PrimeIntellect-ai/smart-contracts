"""

Example object for a client to interface with smart contracts.

This code assumes access to local .json files for smart contract
ABIs, but has not yet been tested with testnet deployed solidity.

Whether being instantiated on a compute node or on prime intellect
infrastructure, different methods should be integrated at different
steps of the training process. 

This code assumes access to the appropriate keys for each of the 
methods meant to be called by a compute node or prime intellect
node. These keys are assumed to be set as environment vars in .env

Moreover, much of this code can be called from a frontend in a
language such as JavaScript and a comparable Web3 library such
as ethers.js. The code that must be invoked on the servers is
attestation code, which is marked with a # DEV comment below.

"""

from web3 import Web3
from dotenv import load_dotenv
import os
import json
import secrets
import socket

class PrimeIntellectRewards:

    """

    Initialize environment variables.

    """

    def __init__(self) -> None:

        load_dotenv()
        self.CRYPTO_REWARDS=os.getenv('CRYPTO_REWARDS')
        self.WEB3_HTTP_PROVIDER=os.getenv('WEB3_HTTP_PROVIDER')
        self.CONTRACT_ADDRESS=os.getenv('CONTRACT_ADDRESS')
        self.CONTRACT_ABI=os.getenv('CONTRACT_ABI')
        self.COMPUTE_NODE_WALLET_PUBLIC_KEY=os.getenv('COMPUTE_NODE_WALLET_PUBLIC_KEY')
        self.COMPUTE_NODE_WALLET_PRIVATE_KEY=os.getenv('COMPUTE_NODE_WALLET_PRIVATE_KEY')
        self.MODEL_TRAINER_WALLET_PUBLIC_KEY=os.getenv('MODEL_TRAINER_WALLET_PUBLIC_KEY')
        self.MODEL_TRAINER_WALLET_PRIVATE_KEY=os.getenv('MODEL_TRAINER_WALLET_PRIVATE_KEY')

        # Connect to chain
        self.web3 = Web3(Web3.HTTPProvider(self.WEB3_HTTP_PROVIDER))
        checksum_contract_address = Web3.to_checksum_address(self.CONTRACT_ADDRESS)
        with open(self.CONTRACT_ABI, "r") as f:
            abi = json.load(f)
        self.contract = self.web3.eth.contract(
            address=checksum_contract_address,
            abi=abi['abi']
        )

        # Hyperparameters
        RANDOM_ATTESTATION_BYTES_LENGTH = 50

    """

    Helper methods denoted with _

    """

    def _crypto_rewards(self) -> bool:
        if self.CRYPTO_REWARDS:
            return True
        return False
    
    def _chain_id(self) -> int:
        return self.web3.eth.chain_id

    def _ip_address(self) -> str:
        hostname = socket.gethostname()
        return socket.gethostbyname(hostname)

    """ DEV

    Attestation submission code for compute nodes.

    """

    def _generate_attestation(self) -> str:

        """

        This attestation is random bytes, itended to be called
        after a certain number of training iterations (i.e. 500).

        The attestation could become a cryptographic proof of
        computation of the training step, but for now the random
        bytes suffice under the assumption of a trusted compute
        node.

        """

        return (
            b"\x00" + \
            secrets.token_bytes(self.RANDOM_ATTESTATION_BYTES_LENGTH) + \
            b"\x00"
        )

    def submit_attestation(self, training_run_id) -> bool:
        try:
            pub_key = self.COMPUTE_NODE_WALLET_PUBLIC_KEY
            pri_key = self.COMPUTE_NODE_WALLET_PRIVATE_KEY
            chain_id = self._chain_id()
            nonce = self.web3.eth.get_transaction_count(pub_key)

            attestation = self._generate_attestation()
            call_function = self.contract.functions.submitAttestation(
                pub_key,
                training_run_id,
                attestation
            ).build_transaction({
                "chainId": chain_id,
                 "from": pub_key,
                 "nonce": nonce
            })

            signed_tx = self.web3.eth.account.sign_transaction(
                call_function,
                private_key=pri_key
            )
            send_tx = self.web3.eth.send_raw_transaction(signed_tx.raw_transaction)
            self.web3.eth.wait_for_transaction_receipt(send_tx)
            return True
        except:
            return False

    """

    Addtional methods which could also be called from a JS frontend.

    """

    def register_model_for_training_run(self, name: str, budget: int) -> int:
        try:
            pub_key = self.MODEL_TRAINER_WALLET_PUBLIC_KEY
            pri_key = self.MODEL_TRAINER_WALLET_PRIVATE_KEY
            chain_id = self._chain_id()
            nonce = self.web3.eth.get_transaction_count(pub_key)

            call_function = self.contract.functions.registerTrainingRun(
                name,
                budget
            ).build_transaction({
                "chainId": chain_id, 
                "from": pub_key, 
                "nonce": nonce
            })

            signed_tx = self.web3.eth.account.sign_transaction(
                call_function,
                private_key=pri_key
            )
            send_tx = self.web3.eth.send_raw_transaction(signed_tx.raw_transaction)
            self.web3.eth.wait_for_transaction_receipt(send_tx)
            return self.contract.functions.registerTrainingRun().call()
        except Exception as e:
            raise Exception('register_model_for_training_run failed with error ', e)

    def register_compute_node_for_training_run(self, ip_address: str, training_run_id: int) -> bool:
        try:
            pub_key = self.COMPUTE_NODE_WALLET_PUBLIC_KEY
            pri_key = self.COMPUTE_NODE_WALLET_PRIVATE_KEY
            chain_id = self._chain_id()
            nonce = self.web3.eth.get_transaction_count(pub_key)

            call_function = self.contract.functions.registerComputeNode(
                pub_key,
                ip_address,
                training_run_id
            ).build_transaction({
                "chainId": chain_id,
                "from": pub_key,
                "nonce": nonce
            })

            signed_tx = self.web3.eth.account.sign_transaction(
                call_function,
                private_key=pri_key
            )
            send_tx = self.web3.eth.send_raw_transaction(signed_tx.raw_transaction)
            self.web3.eth.wait_for_transaction_receipt(send_tx)
            return True
        except:
            return False
        
    def start_training_run(self, training_run_id) -> bool:
        try:
            pub_key = self.COMPUTE_NODE_WALLET_PUBLIC_KEY
            pri_key = self.COMPUTE_NODE_WALLET_PRIVATE_KEY
            chain_id = self._chain_id()
            nonce = self.web3.eth.get_transaction_count(pub_key)

            call_function = self.contract.functions.startTrainingRun(training_run_id).build_transaction({
                "chainId": chain_id,
                "from": pub_key,
                "nonce": nonce
            })

            signed_tx = self.web3.eth.account.sign_transaction(
                call_function,
                private_key=pri_key
            )
            send_tx = self.web3.eth.send_raw_transaction(signed_tx.raw_transaction)
            self.web3.eth.wait_for_transaction_receipt(send_tx)
            return True
        except:
            return False
        
    def end_training_run(self, training_run_id) -> bool:
        try:
            pub_key = self.MODEL_TRAINER_WALLET_PUBLIC_KEY
            pri_key = self.MODEL_TRAINER_WALLET_PRIVATE_KEY
            chain_id = self._chain_id()
            nonce = self.web3.eth.get_transaction_count(pub_key)

            call_function = self.contract.functions.endTrainingRun(training_run_id).build_transaction({
                "chainId": chain_id,
                "from": pub_key,
                "nonce": nonce
            })

            signed_tx = self.web3.eth.account.sign_transaction(
                call_function,
                private_key=pri_key
            )
            send_tx = self.web3.eth.send_raw_transaction(signed_tx.raw_transaction)
            self.web3.eth.wait_for_transaction_receipt(send_tx)
            return True
        except:
            return False

if __name__ == "__main__":
    primeIntellectRewards = PrimeIntellectRewards()
