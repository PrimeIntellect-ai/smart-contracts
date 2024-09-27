// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TrainingManager} from "../src/TrainingManager.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";

contract TrainingManagerTest is Test {
    TrainingManager public trainingManager;
    StakingManager public stakingManager;
    PrimeIntellectToken public PIN;

    address public admin = address(1);
    address public computeNode = address(2);
    address public computeNode2 = address(3);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant MIN_DEPOSIT = 10000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);

        PIN = new PrimeIntellectToken("Prime Intellect Token", "PIN");
        stakingManager = new StakingManager(address(PIN));
        trainingManager = new TrainingManager();

        // Set the TrainingManager address in StakingManager
        stakingManager.setTrainingManager(address(trainingManager));

        // Set the StakingManager address in TrainingManager
        trainingManager.setStakingManager(address(stakingManager));

        PIN.mint(computeNode, INITIAL_SUPPLY);

        trainingManager.addComputeNode(computeNode);

        vm.stopPrank();
    }

    function test_registerNewModel() public {
        vm.startPrank(msg.sender);

        string memory modelName = "Test Model";
        uint256 modelBudget = 1000;

        uint256 trainingRunId = trainingManager.registerModel(
            modelName,
            modelBudget
        );

        console.log("New model registered with trainingRunId:", trainingRunId);

        assertEq(
            trainingManager.name(trainingRunId),
            modelName,
            "Model name not set correctly"
        );
        assertEq(
            trainingManager.budget(trainingRunId),
            modelBudget,
            "Model budget not set correctly"
        );
        assertEq(
            uint256(trainingManager.getModelStatus(trainingRunId)),
            uint256(ITrainingManager.ModelStatus.Registered),
            "Model status not set to Registered"
        );

        assertEq(
            trainingManager.trainingRunIdCount(),
            trainingRunId,
            "trainingRunIdCount not incremented correctly"
        );

        vm.stopPrank();
    }

    function test_registerComputeNode() public {
        vm.startPrank(admin);

        vm.expectRevert("Compute node already registered");
        trainingManager.addComputeNode(computeNode);

        trainingManager.addComputeNode(computeNode2);

        bool isValid = trainingManager.isComputeNodeValid(computeNode2);

        console.log("Compute node address:", computeNode2);
        console.log("Is compute node valid:", isValid);

        assertTrue(isValid, "Compute node should be valid after registration");

        vm.expectRevert("Compute node already registered");
        trainingManager.addComputeNode(computeNode2);

        address anotherComputeNode = address(4);
        trainingManager.addComputeNode(anotherComputeNode);

        bool isAnotherValid = trainingManager.isComputeNodeValid(
            (anotherComputeNode)
        );

        console.log("Another compute node address:", anotherComputeNode);
        console.log("Is another compute node valid:", isAnotherValid);

        assertTrue(
            isAnotherValid,
            "Another compute node should be valid after registration"
        );

        vm.stopPrank();
    }

    function test_joinTrainingRun() public {
        string memory ipAddress = "192.168.1.1";
        uint256 stakeAmount = MIN_DEPOSIT + MIN_DEPOSIT;

        vm.startPrank(admin);

        string memory modelName = "Test Model";
        uint256 modelBudget = 1000;

        uint256 trainingRunId = trainingManager.registerModel(
            modelName,
            modelBudget
        );
        vm.stopPrank();

        vm.startPrank(computeNode);
        console.log(
            "Compute node balance before stake is:",
            PIN.balanceOf(computeNode)
        );

        PIN.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(computeNode, stakeAmount);
        console.log(
            "Compute node balance after stake is:",
            PIN.balanceOf(computeNode)
        );

        bool success = trainingManager.joinTrainingRun(
            computeNode,
            ipAddress,
            trainingRunId
        );

        assertTrue(success, "Failed to join training run");

        (
            string memory name,
            uint256 budget,
            ITrainingManager.ModelStatus status,
            address[] memory computeNodes
        ) = trainingManager.getTrainingRunInfo(trainingRunId);

        console.log("Training Run Info:");
        console.log("Name:", name);
        console.log("Budget:", budget);
        console.log("Status:", uint(status));
        console.log("Compute Nodes:");
        for (uint i = 0; i < computeNodes.length; i++) {
            console.log(computeNodes[i]);
        }
        assertEq(computeNodes.length, 1, "Should have one compute node");
        assertEq(
            computeNodes[0],
            computeNode,
            "Compute node should be added to the training run"
        );

        vm.stopPrank();
    }
}

// function test_submitAttestation() public {

// }

// function test_endTrainingRun() public {

// }
