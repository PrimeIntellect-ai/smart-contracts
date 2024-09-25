// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract StakingManagerTest2 is Test {
    StakingManager public stakingManager;
    TrainingManager public trainingManager;
    PrimeIntellectToken public pinToken;

    address public admin = address(1);
    address public computeNode = address(2);

    uint256 public constant TRAINING_RUN_ID = 1;
    uint256 public constant ATTESTATION_COUNT = 10;
    uint256 public constant REWARD_RATE = 1; // 1 PIN per attestation

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        pinToken = new PrimeIntellectToken("Prime-Intellect-Token", "PIN");
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(
            pinToken,
            ITrainingManager(address(trainingManager)),
            1000
        );

        pinToken.grantRole(pinToken.DEFAULT_ADMIN_ROLE(), address(admin));
        trainingManager.grantRole(
            trainingManager.DEFAULT_ADMIN_ROLE(),
            address(this)
        );

        vm.stopPrank();

        trainingManager.addComputeNode(computeNode);

        vm.startPrank(computeNode);
        trainingManager.joinTrainingRun(
            computeNode,
            "192.168.1.1",
            TRAINING_RUN_ID
        );
        trainingManager.startTrainingRun(TRAINING_RUN_ID);
        for (uint i = 0; i < ATTESTATION_COUNT; i++) {
            trainingManager.submitAttestation(
                computeNode,
                TRAINING_RUN_ID,
                abi.encodePacked("attestation", i)
            );
        }
        trainingManager.endTrainingRun(TRAINING_RUN_ID);
        vm.stopPrank();

        // Simulate time passage for claim delay
        vm.warp(block.timestamp + 8 days);
    }

    function testClaimRewards() public {
        uint256 expectedReward = ATTESTATION_COUNT * REWARD_RATE;

        uint256 initialBalance = pinToken.balanceOf(computeNode);

        vm.prank(computeNode);
        stakingManager.claim();

        uint256 finalBalance = pinToken.balanceOf(computeNode);

        assertEq(
            finalBalance - initialBalance,
            expectedReward,
            "Incorrect reward amount claimed"
        );
    }
}
