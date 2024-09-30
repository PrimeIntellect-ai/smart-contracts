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
        stakingManager = new StakingManager(address(PIN), address(trainingManager));

        // Set the StakingManager address in TrainingManager
        trainingManager.setStakingManager(address(stakingManager));

        PIN.mint(computeNode, INITIAL_SUPPLY);

        trainingManager.addComputeNode(computeNode);

        vm.stopPrank();
    }

    function test_registerNewModel() public {
        vm.startPrank(admin);

        string memory modelName = "Test Model";
        uint256 modelBudget = 1000;

        uint256 trainingRunId = trainingManager.registerModel(modelName, modelBudget);

        assertEq(trainingManager.name(trainingRunId), modelName, "Model name not set correctly");
        assertEq(trainingManager.budget(trainingRunId), modelBudget, "Model budget not set correctly");
        assertEq(
            uint256(trainingManager.getModelStatus(trainingRunId)),
            uint256(ITrainingManager.ModelStatus.Registered),
            "Model status not set to Registered"
        );

        assertEq(trainingManager.trainingRunIdCount(), trainingRunId, "trainingRunIdCount not incremented correctly");

        string memory anotherModel = "Test Model";
        uint256 anotherBudget = 1000;

        vm.expectRevert("Model already registered");
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

        bool isAnotherValid = trainingManager.isComputeNodeValid((anotherComputeNode));

        assertTrue(isAnotherValid, "Another compute node should be valid after registration");

        vm.stopPrank();
    }

    function test_JoinTrainingRun() public {
        string memory ipAddress = "192.168.1.1";
        uint256 stakeAmount = MIN_DEPOSIT + MIN_DEPOSIT;

        vm.startPrank(admin);

        string memory modelName = "Test Model";
        uint256 modelBudget = 1000;

        uint256 trainingRunId = trainingManager.registerModel(modelName, modelBudget);
        vm.stopPrank();

        vm.startPrank(computeNode);

        PIN.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);

        bool success = trainingManager.joinTrainingRun(computeNode, ipAddress, trainingRunId);

        assertTrue(success, "Failed to join training run");

        (string memory name, uint256 budget, ITrainingManager.ModelStatus status, address[] memory computeNodes) =
            trainingManager.getTrainingRunInfo(trainingRunId);

        uint256(status);

        assertEq(name, modelName, "Name should match constructor");
        assertEq(budget, modelBudget, "Budget should match constructor");
        assertEq(computeNodes.length, 1, "Should have one compute node");
        assertEq(computeNodes[0], computeNode, "Compute node should be added to the training run");

        vm.stopPrank();
    }

    /// test to start a training run and submit attestations
    function test_StartAndSubmit() public {
        string memory ipAddress1 = "192.168.1.1";
        uint256 stakeAmount = MIN_DEPOSIT;

        vm.startPrank(admin);

        string memory modelName = "Test Model";
        uint256 modelBudget = 1000;

        uint256 trainingRunId = trainingManager.registerModel(modelName, modelBudget);

        TrainingManager.ModelStatus status0 = trainingManager.getTrainingRunStatus(trainingRunId);

        vm.stopPrank();

        vm.startPrank(computeNode);
        // join run
        PIN.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);
        trainingManager.joinTrainingRun(computeNode, ipAddress1, trainingRunId);
        vm.stopPrank();

        // start run
        vm.startPrank(admin);
        trainingManager.startTrainingRun(trainingRunId);
        vm.stopPrank();

        // submit attestations
        vm.startPrank(computeNode);
        bytes memory attestation = abi.encode("Sample attestation data");

        trainingManager.submitAttestation(computeNode, trainingRunId, attestation);
        uint256 attestationCount = trainingManager.getAttestations(trainingRunId, computeNode);

        assertEq(attestationCount, 1);
        vm.stopPrank();
    }

    function EndTrainingRunTest() public {
        vm.startPrank(admin);

        string memory modelName = "Test Model";
        uint256 modelBudget = 1000;

        uint256 trainingRunId = trainingManager.registerModel(
            modelName,
            modelBudget
        );

        TrainingManager.ModelStatus status0 = trainingManager
            .getTrainingRunStatus(trainingRunId);
        console.log("Training Run Status before start:", uint256(status0)); // log status as uint

        trainingManager.startTrainingRun(trainingRunId);
        console.log("TrainingRunId is:", trainingRunId);

        // Display status after starting training run
        TrainingManager.ModelStatus status1 = trainingManager
            .getTrainingRunStatus(trainingRunId);
        console.log("Training Run Status after start:", uint256(status1)); // log status as uint 1

        trainingManager.endTrainingRun(trainingRunId);

        // Display status after ending training run
        TrainingManager.ModelStatus status2 = trainingManager
            .getTrainingRunStatus(trainingRunId);
        console.log("Training run status after ending:", uint256(status2)); // log status as uint 2
        vm.stopPrank();
    }
}
