# Smart Contracts

This project was developed using forge and tested on a local anvil testnet.

## Setup

### Install

```shell
git submodule update --init --recursive
```

If that doesn't work, you may have to re-initialize the submodules:

```shell
rm .gitmodules
touch .gitmodules
rm -rf lib/openzeppelin-contracts
rm -rf lib/forge-std
git add .
git submodule add https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
git submodule add https://github.com/foundry-rs/forge-std.git lib/forge-std
git submodule update --init --recursive
```

Then you can call `forge build`.

### Build

```shell
forge build
# or to include abis in output to out/<contract>.sol/<contract>.abi.json
forge build --extra-output-files abi
```

### Test

```shell
forge test
```

## Run Locally

Start anvil:

```shell
anvil
```

### Deploy Locally

```shell
./script/deploy.sh
```

Here are some example commands that can be useful for testing.
You can find the parameters by looking at the outputs of `anvil` and `./script/deploy.sh`.

Get attestations count:
```shell
cast call --rpc-url $RPC_URL --private-key $PRIVATE_KEY $TRAINING_MANAGER_CONTRACT_ADDRESS "getAttestationsCount(uint256,address)" $TRAINING_RUN_ID $COMPUTE_NODE
cast call --rpc-url $RPC_URL --private-key $PRIVATE_KEY $TRAINING_MANAGER_CONTRACT_ADDRESS "getAttestationsForComputeNode(uint256,address)" $TRAINING_RUN_ID $COMPUTE_NODE
```

Start a training run:

```shell
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $TRAINING_MANAGER_CONTRACT_ADDRESS "startTrainingRun(uint256)" $TRAINING_RUN_ID
```
