// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/AIToken.sol";
import "../src/AITokenTransferRole.sol";
import "../src/ComputePool.sol";
import "../src/ComputeRegistry.sol";
import "../src/DomainRegistry.sol";
import "../src/PrimeNetwork.sol";
import "../src/StakeManager.sol";
import {RewardsDistributorWorkSubmissionFactory} from "../src/RewardsDistributorWorkSubmissionFactory.sol";

import "./deployment_util.sol";

contract SetupStateScript is DeploymentUtil {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_FEDERATOR");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 poolId = 0;
        string memory deploymentsFile = "./release/deployments.json";

        Deployments memory deployments = getDeployments(deploymentsFile);

        logDeployments(deployments);

        PrimeNetwork primeNetwork = PrimeNetwork(deployments.PrimeNetwork);
        ComputePool computePool = ComputePool(deployments.ComputePool);
        IWorkValidation workValidator = IWorkValidation(deployments.WorkValidator);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Creating domain...");
        uint256 domainId = primeNetwork.createDomain(
            "Decentralized Training", workValidator, "https://primeintellect.ai/training/params"
        );

        console.log("Domain ID:", domainId);

        address computeManager = address(deployer);

        console.log("Creating compute pool...");
        poolId = computePool.createComputePool(domainId, computeManager, "test", "ipfs://legacy", 0);
        poolId = 0;
        console.log("Compute pool ID:", poolId);
        console.log("Starting compute pool:", poolId);
        computePool.startComputePool(poolId);
        computePool.endComputePool(poolId);
        console.log("Ended compute pool:", poolId);
        console.log("Creating compute pool...");
        poolId = computePool.createComputePool(domainId, computeManager, "SYNTHETIC-1", "ipfs://legacy", 0);
        console.log("Compute pool ID:", poolId);
        console.log("Starting compute pool:", poolId);
        computePool.startComputePool(poolId);
        computePool.endComputePool(poolId);
        console.log("Ended compute pool:", poolId);
        // ...

        vm.stopBroadcast();
    }
}
