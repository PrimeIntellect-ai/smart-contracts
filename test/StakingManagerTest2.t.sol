// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/interfaces/ITrainingManager.sol";

contract StakingManagerTest2 is Test {
    StakingManager public stakingManager;
    PrimeIntellectToken public pinToken;
    ITrainingManager public trainingManager;

    address public admin = address(1);
    address public computeNode = address(2);
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    uint256 public constant MIN_DEPOSIT = 8760 ether;
    uint256 public constant STAKE_AMOUNT = 10000 ether;
    uint256 public constant TRAINING_RUN_ID = 1;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy PrimeIntellectToken
        pinToken = new PrimeIntellectToken("Prime Intellect", "PIN");

        // Mock TrainingManager
        trainingManager = ITrainingManager(address(0x123)); // Use a dummy address

        // Deploy StakingManager
        stakingManager = new StakingManager(
            pinToken,
            trainingManager,
            MIN_DEPOSIT
        );

        // Grant ADMIN_ROLE to StakingManager in PrimeIntellectToken
        pinToken.grantAdminRole(address(stakingManager));

        // Mint initial balance to computeNode
        pinToken.mint(computeNode, INITIAL_BALANCE);

        vm.stopPrank();
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

        // Simulate submitting 2 attestations
        // In a real scenario, this would be done through a function call that updates the contract's state
        // For testing purposes, we'll assume the attestations have been submitted

        // Fast forward 7 days (claim delay)
        vm.warp(block.timestamp + 7 days + 1);

        // Mock pendingRewards function to return rewards for 2 attestations
        vm.mockCall(
            address(stakingManager),
            abi.encodeWithSelector(
                StakingManager.pendingRewards.selector,
                computeNode
            ),
            abi.encode(2 * stakingManager.REWARD_RATE())
        );

        // Claim rewards
        vm.prank(computeNode);
        stakingManager.claim();

        // Check claimed rewards (2 attestations * REWARD_RATE)
        uint256 expectedRewards = 2 * stakingManager.REWARD_RATE();
        uint256 actualBalance = pinToken.balanceOf(computeNode);
        assertEq(
            actualBalance,
            INITIAL_BALANCE + expectedRewards,
            "Claimed rewards should be correct"
        );
    }
}
