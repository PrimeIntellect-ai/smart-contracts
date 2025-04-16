// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * ---- IMPORTANT NOTE ----
 *
 * YOU MUST KEEP THE ORDER OF THESE STRUCT FIELDS IN ALPHABETICAL ORDER
 * BECAUSE FOUNDRY JUST REORDERS THE JSON ALPHABETICALLY
 * ON LOAD AND COMPLETELY IGNORES FIELD NAMES
 *
 */
struct Deployments {
    address AIToken;
    address ComputePool;
    address ComputeRegistry;
    address DomainRegistry;
    address PrimeNetwork;
    address RewardsDistributorFactory;
    address StakeManager;
    address WorkValidator;
}

struct DeploymentsInternal {
    bytes32 AIToken;
    bytes32 ComputePool;
    bytes32 ComputeRegistry;
    bytes32 DomainRegistry;
    bytes32 PrimeNetwork;
    bytes32 RewardsDistributorFactory;
    bytes32 StakeManager;
    bytes32 WorkValidator;
}

contract DeploymentUtil is Script {
    function getDeployments(string memory location) internal view returns (Deployments memory) {
        string memory json = vm.readFile(location);
        bytes memory data = vm.parseJson(json);

        console.log("Data:", vm.toString(data));

        DeploymentsInternal memory deploymentsInternal = abi.decode(data, (DeploymentsInternal));

        Deployments memory deployments = Deployments({
            AIToken: address(bytes20(deploymentsInternal.AIToken << (8 * 12))),
            ComputePool: address(bytes20(deploymentsInternal.ComputePool << (8 * 12))),
            ComputeRegistry: address(bytes20(deploymentsInternal.ComputeRegistry << (8 * 12))),
            DomainRegistry: address(bytes20(deploymentsInternal.DomainRegistry << (8 * 12))),
            PrimeNetwork: address(bytes20(deploymentsInternal.PrimeNetwork << (8 * 12))),
            RewardsDistributorFactory: address(bytes20(deploymentsInternal.RewardsDistributorFactory << (8 * 12))),
            StakeManager: address(bytes20(deploymentsInternal.StakeManager << (8 * 12))),
            WorkValidator: address(bytes20(deploymentsInternal.WorkValidator << (8 * 12)))
        });

        return deployments;
    }

    function writeDeployments(Deployments memory deployments, string memory location) internal {
        if (vm.exists(location)) {
            vm.removeFile(location);
        }

        vm.serializeAddress("contracts", "AIToken", address(deployments.AIToken));
        vm.serializeAddress("contracts", "ComputeRegistry", address(deployments.ComputeRegistry));
        vm.serializeAddress("contracts", "ComputePool", address(deployments.ComputePool));
        vm.serializeAddress("contracts", "DomainRegistry", address(deployments.DomainRegistry));
        vm.serializeAddress("contracts", "PrimeNetwork", address(deployments.PrimeNetwork));
        vm.serializeAddress("contracts", "StakeManager", address(deployments.StakeManager));
        vm.serializeAddress("contracts", "RewardsDistributorFactory", address(deployments.RewardsDistributorFactory));

        string memory finalJson = vm.serializeAddress("contracts", "WorkValidator", address(deployments.WorkValidator));

        vm.writeJson(finalJson, location);
    }

    function logDeployments(Deployments memory deployments) internal pure {
        console.log("AIToken:", address(deployments.AIToken));
        console.log("ComputePool:", address(deployments.ComputePool));
        console.log("ComputeRegistry:", address(deployments.ComputeRegistry));
        console.log("DomainRegistry:", address(deployments.DomainRegistry));
        console.log("PrimeNetwork:", address(deployments.PrimeNetwork));
        console.log("RewardsDistributorFactory:", address(deployments.RewardsDistributorFactory));
        console.log("StakeManager:", address(deployments.StakeManager));
        console.log("WorkValidator:", address(deployments.WorkValidator));
    }
}
