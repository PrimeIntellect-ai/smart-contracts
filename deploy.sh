#!/bin/bash

# Set default RPC URL if not provided
if [ -z "$RPC_URL" ]; then
  export RPC_URL="http://localhost:8545"
fi

export PRIVATE_KEY_FEDERATOR="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
export PRIVATE_KEY_VALIDATOR="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

mkdir -p ./release

forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --via-ir

forge inspect --via-ir --json AIToken abi > ./release/ai_token.json
forge inspect --via-ir --json ComputePool abi > ./release/compute_pool.json
forge inspect --via-ir --json ComputeRegistry abi > ./release/compute_registry.json
forge inspect --via-ir --json DomainRegistry abi > ./release/domain_registry.json
forge inspect --via-ir --json PrimeNetwork abi > ./release/prime_network.json
forge inspect --via-ir --json StakeManager abi > ./release/stake_manager.json
forge inspect --via-ir --json RewardsDistributorFixed abi > ./release/rewards_distributor.json