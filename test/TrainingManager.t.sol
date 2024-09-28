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
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(
            address(PIN),
            address(trainingManager)
        );

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

        string memory anotherModel = "Test Model";
        uint256 anotherBudget = 1000;

        vm.expectRevert(
            "Training run with same name and budget already exists."
        );
        trainingManager.registerModel(anotherModel, anotherBudget);

        vm.stopPrank();
    }

    function test_registerComputeNode() public {
        vm.startPrank(admin);

        vm.expectRevert("Compute node already registered");
        trainingManager.addComputeNode(computeNode);

        trainingManager.addComputeNode(computeNode2);

        bool isValid = trainingManager.isComputeNodeValid(computeNode2);

        
        

        assertTrue(isValid, "Compute node should be valid after registration");

        vm.expectRevert("Compute node already registered");
        trainingManager.addComputeNode(computeNode2);

        address anotherComputeNode = address(4);
        trainingManager.addComputeNode(anotherComputeNode);

        bool isAnotherValid = trainingManager.isComputeNodeValid(
            (anotherComputeNode)
        );

        
        

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
        

        PIN.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(computeNode, stakeAmount);
        

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

        uint256(status);

        assertEq(name, modelName, "Name should match constructor");
        assertEq(budget, modelBudget, "Budget should match constructor");
        assertEq(computeNodes.length, 1, "Should have one compute node");
        assertEq(
            computeNodes[0],
            computeNode,
            "Compute node should be added to the training run"
        );

        vm.stopPrank();
    }
}
