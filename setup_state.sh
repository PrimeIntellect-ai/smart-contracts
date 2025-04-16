#!/bin/bash

if [ -z "$RPC_URL" ]; then
  export RPC_URL="http://localhost:8545"
fi

if [ -z "$PRIVATE_KEY_FEDERATOR" ]; then
  export PRIVATE_KEY_FEDERATOR="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
fi

forge script script/SetupState.s.sol:SetupStateScript --rpc-url $RPC_URL --broadcast --via-ir