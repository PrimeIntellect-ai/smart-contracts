// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";

contract StakingManagerTest is Test {
    StakingManager public stakingManager;
    TrainingManager public trainingManager;
    PrimeIntellectToken public PIN;

    address public admin = address(1);
    address public computeNode = address(2);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant MIN_DEPOSIT = 10000;
    uint256 public constant REWARD_RATE = 1 * 1e18;

    function setUp() public {
        vm.startPrank(admin);

        PIN = new PrimeIntellectToken("Prime-Intellect-Token", "PIN");
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(address(PIN));

        // Set the TrainingManager address in StakingManager
        stakingManager.setTrainingManager(address(trainingManager));

        // Set the StakingManager address in TrainingManager
        trainingManager.setStakingManager(address(stakingManager));

        PIN.approve(computeNode, INITIAL_SUPPLY);
        PIN.mint(computeNode, INITIAL_SUPPLY);
        trainingManager.addComputeNode(computeNode);
        vm.stopPrank();

        console.log("MIN_DEPOSIT:", stakingManager.MIN_DEPOSIT());
    }

    /// @notice helper function used in succeeding test cases
    function _setupMockTrainingRuns(
        uint256[] memory attestationCounts
    ) internal returns (uint256[] memory) {
        uint256[] memory trainingRunIds = new uint256[](
            attestationCounts.length
        );

        for (uint256 j = 0; j < attestationCounts.length; j++) {
            vm.startPrank(admin);

            uint256 trainingRunId = trainingManager.registerModel(
                string(abi.encodePacked("TestModel", j)),
                1000 * 1e18
            );

            // Join the training run before starting it
            trainingManager.joinTrainingRun(
                computeNode,
                "192.168.1.1",
                trainingRunId
            );

            // Start the training run
            trainingManager.startTrainingRun(trainingRunId);

            /// @notice allows us to set multiple training runs j
            /// each with number of attestations i in succeeding functions
            for (uint256 i = 0; i < attestationCounts[j]; i++) {
                trainingManager.submitAttestation(
                    computeNode,
                    trainingRunId,
                    abi.encodePacked("attestation", i)
                );
            }

            trainingManager.endTrainingRun(trainingRunId);

            uint256 endTime = block.timestamp;
            vm.mockCall(
                address(trainingManager),
                abi.encodeWithSelector(
                    trainingManager.getTrainingRunEndTime.selector,
                    trainingRunId
                ),
                abi.encode(endTime)
            );

            vm.stopPrank();

            trainingRunIds[j] = trainingRunId;
        }

        return trainingRunIds;
    }

    function testClaimMultipleRuns() public {
        uint256 stakeAmount = stakingManager.MIN_DEPOSIT() +
            stakingManager.MIN_DEPOSIT();
        console.log("Stake amount:", stakeAmount);

        // staking
        vm.startPrank(computeNode);
        PIN.approve(address(stakingManager), stakeAmount);
        console.log("Staking pin tokens");
        stakingManager.stake(computeNode, stakeAmount);
        vm.stopPrank();

        // create mock training runs using function above
        uint256[] memory attestationCounts = new uint256[](3);
        attestationCounts[0] = 10;
        attestationCounts[1] = 5;
        attestationCounts[2] = 8;

        _setupMockTrainingRuns(attestationCounts);

        vm.warp(block.timestamp + 8 days);

        uint256 initialBalance = PIN.balanceOf(computeNode);

        vm.prank(computeNode);
        console.log("Claiming rewards");
        stakingManager.claim();

        uint256 expectedRewards = 23 * REWARD_RATE; // 10 + 5 + 8
        uint256 finalBalance = PIN.balanceOf(computeNode);
        assertEq(
            finalBalance,
            initialBalance + expectedRewards,
            "Incorrect rewards claimed"
        );
    }
}
