// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SyntheticDataWorkValidator.sol";
import "./deployment_util.sol";

contract DeployWorkValidatorScript is DeploymentUtil {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_FEDERATOR");
        string memory deploymentsFile = "./release/deployments.json";

        Deployments memory deployments = getDeployments(deploymentsFile);

        logDeployments(deployments);
        // Get configuration from environment variables
        uint256 domainId = vm.envUint("DOMAIN_ID");
        address computePool = deployments.ComputePool;
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

        deployments.WorkValidator = address(workValidator);

        // Log deployed address
        console.log("Deployed SyntheticDataWorkValidator:", address(workValidator));

        // keep these in the same order as in the Deploy script
        writeDeployments(deployments, deploymentsFile);
    }
}
