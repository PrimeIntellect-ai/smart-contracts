#!/bin/bash

export PRIVATE_KEY_FEDERATOR="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

export DOMAIN_ID=0
export COMPUTE_POOL_ADDRESS=0x0165878A594ca255338adfa4d48449f69242Eb8F

forge script script/DeployWorkValidator.s.sol:DeployWorkValidatorScript --rpc-url localhost:8545 --broadcast --via-ir
