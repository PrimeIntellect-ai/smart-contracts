#!/bin/bash

# Set default RPC URL if not provided
if [ -z "$RPC_URL" ]; then
  export RPC_URL="http://localhost:8545"
fi

if [ -z "$COMPUTE_POOL_ADDRESS" ]; then
  export COMPUTE_POOL_ADDRESS=0x610178dA211FEF7D417bC0e6FeD39F05609AD788
fi

if [ -z "$DOMAIN_ID" ]; then
  export DOMAIN_ID=0
fi

if [ -z "$PRIVATE_KEY_FEDERATOR" ]; then
  export PRIVATE_KEY_FEDERATOR="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
fi

forge script script/DeployWorkValidator.s.sol:DeployWorkValidatorScript --rpc-url $RPC_URL --broadcast --via-ir

forge inspect --via-ir --json SyntheticDataWorkValidator abi > ./release/synthetic_data_work_validator.json
