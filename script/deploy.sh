#!/bin/bash

# Set the RPC URL and private key
RPC_URL="http://127.0.0.1:8545"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Deploy TrainingManager
echo "Deploying TrainingManager..."
TRAINING_MANAGER=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/TrainingManager.sol:TrainingManager | grep "Deployed to:" | awk '{print $3}')
echo "TrainingManager deployed to: $TRAINING_MANAGER"

# Deploy PrimeIntellectToken
echo "Deploying PrimeIntellectToken..."
PI_TOKEN=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/PrimeIntellectToken.sol:PrimeIntellectToken --constructor-args "Prime-Intellect-Token" "PI" | grep "Deployed to:" | awk '{print $3}')
echo "PrimeIntellectToken deployed to: $PI_TOKEN"

# Deploy StakingManager
echo "Deploying StakingManager..."
STAKING_MANAGER=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/StakingManager.sol:StakingManager --constructor-args $PI_TOKEN $TRAINING_MANAGER | grep "Deployed to:" | awk '{print $3}')
echo "StakingManager deployed to: $STAKING_MANAGER"

# Set StakingManager address in TrainingManager
echo "Setting StakingManager address in TrainingManager..."
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $TRAINING_MANAGER "setStakingManager(address)" $STAKING_MANAGER

# Get the deployer's address
DEPLOYER_ADDRESS=$(cast wallet address $PRIVATE_KEY)
echo "Deployer address: $DEPLOYER_ADDRESS"

# Mint initial supply of PI tokens to the deployer
INITIAL_SUPPLY=1000000000000000000000000  # 1,000,000 tokens with 18 decimals
echo "Minting initial supply of PI tokens..."
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $PI_TOKEN "mint(address,uint256)" $DEPLOYER_ADDRESS $INITIAL_SUPPLY

echo "Deployment and minting completed successfully!"
