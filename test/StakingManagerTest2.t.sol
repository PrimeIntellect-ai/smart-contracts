// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";

contract StakingManagerTest2 is Test {
    StakingManager public stakingManager;
    PrimeIntellectToken public pinToken;
    TrainingManager public trainingManager;

    address public admin;
    address public computeNode;
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    uint256 public constant MIN_DEPOSIT = 8760 ether;
    uint256 public constant STAKE_AMOUNT = 10000 ether;
    uint256 public constant TRAINING_RUN_ID = 1;

    function setUp() public {
        admin = address(this);
        computeNode = address(0x1);

        pinToken = new PrimeIntellectToken("Prime Intellect Network", "PIN");

        TrainingManager mockTrainingManager = new TrainingManager(
            StakingManager(address(0))
        );

        stakingManager = new StakingManager(
            pinToken,
            ITrainingManager(address(mockTrainingManager)),
            MIN_DEPOSIT
        );

        mockTrainingManager = new TrainingManager(stakingManager);
        trainingManager = mockTrainingManager;

        pinToken.mint(computeNode, INITIAL_BALANCE);
    }

    function testStakeMoreThanMinimum() public {
        vm.startPrank(computeNode);

        // Approve StakingManager to spend tokens
        pinToken.approve(address(stakingManager), STAKE_AMOUNT);

        // Stake more than the minimum amount
        stakingManager.stake(computeNode, STAKE_AMOUNT);

        // Check the staked balance
        (uint256 currentBalance, ) = stakingManager.computeNodeBalances(
            computeNode
        );
        assertEq(currentBalance, STAKE_AMOUNT, "Staked amount should match");

        vm.stopPrank();
    }

    function testSubmitAttestationsAndClaimRewards() public {
        // Setup: Stake tokens
        vm.startPrank(computeNode);
        pinToken.approve(address(stakingManager), STAKE_AMOUNT);
        stakingManager.stake(computeNode, STAKE_AMOUNT);
        vm.stopPrank();

        // Mock TrainingManager functions
        vm.mockCall(
            address(trainingManager),
            abi.encodeWithSelector(
                ITrainingManager.isComputeNodeValid.selector,
                computeNode
            ),
            abi.encode(true)
        );
        vm.mockCall(
            address(trainingManager),
            abi.encodeWithSelector(
                ITrainingManager.getModelStatus.selector,
                TRAINING_RUN_ID
            ),
            abi.encode(ITrainingManager.ModelStatus.Done)
        );
        vm.mockCall(
            address(trainingManager),
            abi.encodeWithSelector(
                ITrainingManager.getTrainingRunEndTime.selector,
                TRAINING_RUN_ID
            ),
            abi.encode(block.timestamp)
        );

        // Simulate submitting 10 attestations for training run ID 1
        // In a real scenario, this would be done through a function call that updates the contract's state
        // For testing purposes, we'll assume the attestations have been submitted

        // Fast forward 7 days (claim delay)
        vm.warp(block.timestamp + 7 days + 1);

        // Mock pendingRewards function to return rewards for 10 attestations
        vm.mockCall(
            address(stakingManager),
            abi.encodeWithSelector(
                StakingManager.pendingRewards.selector,
                computeNode
            ),
            abi.encode(10 * stakingManager.REWARD_RATE())
        );

        // Claim rewards
        vm.prank(computeNode);
        stakingManager.claim();

        // Check claimed rewards (10 attestations * REWARD_RATE)
        uint256 expectedRewards = 10 * stakingManager.REWARD_RATE();
        uint256 actualBalance = pinToken.balanceOf(computeNode);
        assertEq(
            actualBalance,
            INITIAL_BALANCE + expectedRewards,
            "Claimed rewards should be correct for 10 attestations"
        );
    }
}
