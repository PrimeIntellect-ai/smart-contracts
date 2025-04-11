// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SyntheticDataWorkValidator.sol";

contract DeployWorkValidatorScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_FEDERATOR");

        // Get configuration from environment variables
        uint256 domainId = vm.envUint("DOMAIN_ID");
        address computePool = vm.envAddress("COMPUTE_POOL_ADDRESS");
        uint256 workValidityPeriod = 1 days;
        console.log("Configuration:");
        console.log("  Domain ID:", domainId);
        console.log("  Compute Pool:", computePool);
        console.log("  Work Validity Period:", workValidityPeriod);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SyntheticDataWorkValidator
        SyntheticDataWorkValidator workValidator =
            new SyntheticDataWorkValidator(domainId, computePool, workValidityPeriod);

        vm.stopBroadcast();

        // Log deployed address
        console.log("Deployed SyntheticDataWorkValidator:", address(workValidator));

        string memory finalJson = vm.serializeAddress("contracts", "work_validator", address(workValidator));
        vm.writeJson(finalJson, "./release/synthetic_data_work_validator.json");
    }
}
