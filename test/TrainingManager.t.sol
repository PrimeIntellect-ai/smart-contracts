// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TrainingManager} from "../src/TrainingManager.sol";
import "../src/StakingManager.sol";
import "../src/AsimovToken.sol";

contract TrainingManagerTest is Test {
    TrainingManager public trainingManager;
    StakingManager public stakingManager;
    AsimovToken public ASI;

    address public admin = address(1);
    address public computeNode = address(2);
    address public computeNode2 = address(3);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant MIN_DEPOSIT = 10000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);

        ASI = new AsimovToken("Prime Intellect Token", "ASI");
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(
            address(ASI),
            address(trainingManager)
        );

        // Set the StakingManager address in TrainingManager
        trainingManager.setStakingManager(address(stakingManager));

        ASI.mint(computeNode, INITIAL_SUPPLY);

        trainingManager.whitelistComputeNode(computeNode);

        vm.stopPrank();
    }

    function test_registerNewModel() public {
        vm.startPrank(admin);

        string memory modelName = "Test Model";

        uint256 trainingRunId = trainingManager.registerModel(
            modelName
        );

        assertEq(
            trainingManager.name(trainingRunId),
            modelName,
            "Model name not set correctly"
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

        vm.expectRevert("Model already registered");
        trainingManager.registerModel(anotherModel);

        vm.stopPrank();
    }

    function test_registerComputeNode() public {
        vm.startPrank(admin);

        vm.expectRevert("Compute node already registered");
        trainingManager.whitelistComputeNode(computeNode);

        trainingManager.whitelistComputeNode(computeNode2);

        bool isValid = trainingManager.isComputeNodeWhitelisted(computeNode2);

        assertTrue(isValid, "Compute node should be valid after registration");

        vm.expectRevert("Compute node already registered");
        trainingManager.whitelistComputeNode(computeNode2);

        address anotherComputeNode = address(4);
        trainingManager.whitelistComputeNode(anotherComputeNode);

        bool isAnotherValid = trainingManager.isComputeNodeWhitelisted(
            (anotherComputeNode)
        );

        assertTrue(
            isAnotherValid,
            "Another compute node should be valid after registration"
        );

        vm.stopPrank();
    }

    function test_JoinTrainingRun() public {
        uint256 stakeAmount = MIN_DEPOSIT + MIN_DEPOSIT;

        vm.startPrank(admin);

        string memory modelName = "Test Model";

        uint256 trainingRunId = trainingManager.registerModel(
            modelName
        );
        vm.stopPrank();

        vm.startPrank(computeNode);

        ASI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);

        bool success = trainingManager.joinTrainingRun(
            computeNode,
            trainingRunId
        );

        assertTrue(success, "Failed to join training run");

        (
            string memory name,
            ITrainingManager.ModelStatus status,
            address[] memory computeNodes
        ) = trainingManager.getTrainingRunInfo(trainingRunId);

        uint256(status);

        assertEq(name, modelName, "Name should match constructor");
        assertEq(computeNodes.length, 1, "Should have one compute node");
        assertEq(
            computeNodes[0],
            computeNode,
            "Compute node should be added to the training run"
        );

        vm.stopPrank();
    }

    /// test to start a training run and submit attestations
    function test_StartAndSubmit() public {
        uint256 stakeAmount = MIN_DEPOSIT;

        vm.startPrank(admin);

        string memory modelName = "Test Model";

        uint256 trainingRunId = trainingManager.registerModel(
            modelName
        );

        vm.stopPrank();

        vm.startPrank(computeNode);
        // join run
        ASI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);
        trainingManager.joinTrainingRun(computeNode, trainingRunId);
        vm.stopPrank();

        // start run
        vm.startPrank(admin);
        trainingManager.startTrainingRun(trainingRunId);
        vm.stopPrank();

        // submit attestations
        vm.startPrank(computeNode);
        bytes memory attestation = abi.encode("Sample attestation data");

        trainingManager.submitAttestation(
            computeNode,
            trainingRunId,
            attestation
        );
        uint256 attestationCount = trainingManager.getAttestationsCount(
            trainingRunId,
            computeNode
        );

        assertEq(attestationCount, 1);
        vm.stopPrank();
    }

    function EndTrainingRunTest() public {
        vm.startPrank(admin);

        string memory modelName = "Test Model";

        uint256 trainingRunId = trainingManager.registerModel(
            modelName
        );

        TrainingManager.ModelStatus status0 = trainingManager.getModelStatus(
            trainingRunId
        );
        console.log("Training Run Status before start:", uint256(status0)); // log status as uint

        trainingManager.startTrainingRun(trainingRunId);
        console.log("TrainingRunId is:", trainingRunId);

        // Display status after starting training run
        TrainingManager.ModelStatus status1 = trainingManager.getModelStatus(
            trainingRunId
        );
        console.log("Training Run Status after start:", uint256(status1)); // log status as uint 1

        trainingManager.endTrainingRun(trainingRunId);

        // Display status after ending training run
        TrainingManager.ModelStatus status2 = trainingManager.getModelStatus(
            trainingRunId
        );
        console.log("Training run status after ending:", uint256(status2)); // log status as uint 2
        vm.stopPrank();
    }

    function GetAttestationsForRun() public {}
}
