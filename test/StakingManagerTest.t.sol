// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";

contract StakingManagerTest is Test {
    StakingManager public stakingManager;
    TrainingManager public trainingManager;
    PrimeIntellectToken public PI;

    address public admin = address(1);
    address public computeNode = address(2);

    uint256 public constant INITIAL_SUPPLY = 100000 * 10 ** 18; // 100,000 tokens
    uint256 public constant MIN_DEPOSIT = 10000 * 10 ** 18; // 1,000 tokens

    function setUp() public {
        vm.startPrank(admin);

        PI = new PrimeIntellectToken("Prime-Intellect-Token", "PI");
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(
            address(PI),
            address(trainingManager)
        );

        PI.grantRole(PI.MINTER_ROLE(), address(stakingManager));

        // Set the StakingManager address in TrainingManager
        trainingManager.setStakingManager(address(stakingManager));

        PI.mint(computeNode, INITIAL_SUPPLY);

        trainingManager.whitelistComputeNode(computeNode);

        vm.stopPrank();
    }

    function test_stake() public {
        uint256 stakeAmount = MIN_DEPOSIT + 1;

        vm.startPrank(computeNode);

        uint256 initialPIBalance = PI.balanceOf(computeNode);
        uint256 initialStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );

        PI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);

        uint256 finalPIBalance = PI.balanceOf(computeNode);
        uint256 finalStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );

        assertEq(
            finalPIBalance,
            initialPIBalance - stakeAmount,
            "PI balance should decrease by staked amount"
        );

        // check if the staked balance increased by staked amount
        assertEq(
            finalStakedBalance,
            initialStakedBalance + stakeAmount,
            "Staked balance should increase by staked amount"
        );

        assertTrue(
            stakeAmount > stakingManager.MIN_DEPOSIT(),
            "Must be greater than min deposit"
        );

        assertEq(
            PI.balanceOf(address(stakingManager)),
            stakeAmount,
            "StakingManager balance should match staked amount"
        );

        vm.stopPrank();

        vm.startPrank(computeNode);
        uint256 lowStakeAmount = stakingManager.MIN_DEPOSIT() - 1;
        PI.approve(address(stakingManager), lowStakeAmount);
        vm.expectRevert("Must be greater than min deposit");
        stakingManager.stake(lowStakeAmount);
        vm.stopPrank();
    }

    function testMultipleStakes() public {
        uint256 stakeAmount = MIN_DEPOSIT + MIN_DEPOSIT;

        address computeNode2 = address(3);
        address computeNode3 = address(4);
        address computeNode4 = address(5);

        vm.startPrank(admin);
        PI.mint(computeNode2, INITIAL_SUPPLY);
        PI.mint(computeNode3, INITIAL_SUPPLY);
        PI.mint(computeNode4, INITIAL_SUPPLY);

        trainingManager.whitelistComputeNode(computeNode2);
        trainingManager.whitelistComputeNode(computeNode3);
        trainingManager.whitelistComputeNode(computeNode4);
        vm.stopPrank();

        // compute node 1
        vm.startPrank(computeNode);
        PI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);

        uint256 finalStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );
        assertEq(
            finalStakedBalance,
            stakeAmount,
            "Staked balance should equal first stake for compute node"
        );
        vm.stopPrank();

        // compute node 2
        vm.startPrank(computeNode2);
        PI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);
        uint256 finalStakedBalance2 = stakingManager.getComputeNodeBalance(
            computeNode2
        );
        assertEq(
            finalStakedBalance2,
            stakeAmount,
            "Staked balance should equal first stake for compute node"
        );
        vm.stopPrank();

        // compute node 3
        vm.startPrank(computeNode3);
        PI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);

        uint256 finalStakedBalance3 = stakingManager.getComputeNodeBalance(
            computeNode3
        );
        assertEq(
            finalStakedBalance3,
            stakeAmount,
            "Staked balance should equal first stake for compute node"
        );
        vm.stopPrank();
        assertEq(
            finalStakedBalance2,
            finalStakedBalance3,
            "Compute node 2 and compute node 3 should stake the same amounts"
        );
    }

    function test_withdraw() public {
        uint256 stakeAmount = MIN_DEPOSIT + 1000 * 10 ** 18; // min deposit + 1000 tokens

        vm.startPrank(computeNode);

        PI.approve(address(stakingManager), stakeAmount);
        stakingManager.stake(stakeAmount);

        uint256 stakedBalanceBeforeWithdraw = stakingManager
            .getComputeNodeBalance(computeNode);

        uint256 withdrawAmount = MIN_DEPOSIT;

        // withdraw step
        stakingManager.withdraw(MIN_DEPOSIT);

        uint256 finalStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );

        assertEq(
            finalStakedBalance,
            stakedBalanceBeforeWithdraw - withdrawAmount,
            "PI balance should decrease by withdraw amount"
        );

        vm.stopPrank();
    }

}
