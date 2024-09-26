// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TrainingManager} from "../src/TrainingManager.sol";
import "../src/interfaces/ITrainingManager.sol";

contract TrainingManagerTest is Test {
    TrainingManager public trainingManager;

    address public admin = address(1);
    address public computeNode = address(2);

    function setUp() public {
        vm.startPrank(admin);

        trainingManager = new TrainingManager();

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

        trainingManager.addComputeNode(computeNode);

        bool isValid = trainingManager.isComputeNodeValid(computeNode);

        console.log("Compute node address:", computeNode);
        console.log("Is compute node valid:", isValid);

        assertTrue(isValid, "Compute node should be valid after registration");

        vm.expectRevert("Compute node already registered");
        trainingManager.addComputeNode(computeNode);

        address anotherComputeNode = address(3);
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

    // function test_startTrainingRun() public {

    // }

    // function test_submitAttestation() public {

    // }

    // function test_endTrainingRun() public {

    // }
}
