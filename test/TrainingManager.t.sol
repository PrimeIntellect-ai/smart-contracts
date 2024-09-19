pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TrainingManager} from "../src/TrainingManager.sol";

contract CounterTest is Test {
    TrainingManager public trainingManager;
    trainingRunId public uint256;

    function setUp() public {
        trainingManager = new TrainingManager();
    }

    function test_registerTrainingRun() public {
        trainingRunId = trainingManager.registerTrainingRun("test", 10);
        assertEq(trainingManager.getTrainingRunStatus(id), ModelStatus.Registered);
        assertEq(trainingManager.name(), "test);
        assertEq(trainingManager.budget(), 10);
    }

    function test_registerComputeNode() public {
        
    }

    function test_startTrainingRun() public {
        
    }

    function test_submitAttestation() public {
        
    }

    function test_endTrainingRun() public {
        
    }
}
