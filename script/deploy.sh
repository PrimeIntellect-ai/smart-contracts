#!/bin/bash

ENV=${1:-local}  # Default to 'local' if no argument provided

# Load environment variables from the specified .env file
if [ -f ".env.${ENV}" ]; then
    source ".env.${ENV}"
    echo "Using environment: ${ENV}"
else
    echo "Error: Environment file .env.${ENV} not found"
    exit 1
fi

# Set the RPC URL and private key
RPC_URL=${DEPLOY_RPC_URL:-"http://127.0.0.1:8545"}
PRIVATE_KEY=${DEPLOY_PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Get the deployer's address
DEPLOYER_ADDRESS=$(cast wallet address $PRIVATE_KEY)
echo "Deployer address: $DEPLOYER_ADDRESS"
echo ""

# Deploy TrainingManager
echo "Deploying TrainingManager..."
TRAINING_MANAGER=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/TrainingManager.sol:TrainingManager | grep "Deployed to:" | awk '{print $3}')
echo "--> TrainingManager deployed to: $TRAINING_MANAGER"

# Deploy AsimovToken
echo "Deploying AsimovToken..."
ASI_TOKEN=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/AsimovToken.sol:AsimovToken --constructor-args "Asimov-Token" "ASI" | grep "Deployed to:" | awk '{print $3}')
echo "--> AsimovToken deployed to: $ASI_TOKEN"

# Deploy StakingManager
echo "Deploying StakingManager..."
STAKING_MANAGER=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/StakingManager.sol:StakingManager --constructor-args $ASI_TOKEN $TRAINING_MANAGER | grep "Deployed to:" | awk '{print $3}')
echo "--> StakingManager deployed to: $STAKING_MANAGER"

# Set StakingManager address in TrainingManager
echo "Setting StakingManager address in TrainingManager..."
if cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $TRAINING_MANAGER "setStakingManager(address)" $STAKING_MANAGER > /dev/null 2>&1; then
    echo "--> Successfully set StakingManager address in TrainingManager to $STAKING_MANAGER"
else
    echo "--> Failed to set StakingManager address"
    exit 1
fi

# Mint initial supply of ASI tokens to the deployer
INITIAL_SUPPLY=1000000000000000000000000  # 1,000,000 tokens with 18 decimals
echo "Minting initial supply of ASI tokens..."
if cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $ASI_TOKEN "mint(address,uint256)" $DEPLOYER_ADDRESS $INITIAL_SUPPLY > /dev/null 2>&1; then
    echo "--> Successfully minted initial supply of $INITIAL_SUPPLY ASI tokens to $DEPLOYER_ADDRESS"
else
    echo "--> Failed to mint initial supply"
    exit 1
fi

echo ""
echo "Deployment and minting completed successfully!"
