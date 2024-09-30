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
    PrimeIntellectToken public PIN;

    address public admin = address(1);
    address public computeNode = address(2);

    uint256 public constant INITIAL_SUPPLY = 100000 * 10 ** 18; // 100,000 tokens
    uint256 public constant MIN_DEPOSIT = 10000 * 10 ** 18; // 1,000 tokens

    function setUp() public {
        vm.startPrank(admin);

        PIN = new PrimeIntellectToken("Prime-Intellect-Token", "PIN");
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(
            address(PIN),
            address(trainingManager)
        );
        

        PIN.grantRole(PIN.MINTER_ROLE(), address(stakingManager));

        // Set the StakingManager address in TrainingManager
        trainingManager.setStakingManager(address(stakingManager));
        

        PIN.mint(computeNode, INITIAL_SUPPLY);
        

        trainingManager.addComputeNode(computeNode);
        

        vm.stopPrank();
        
    }

    function test_stake() public {
        uint256 stakeAmount = MIN_DEPOSIT + 1;

        vm.startPrank(computeNode);

        uint256 initialPINBalance = PIN.balanceOf(computeNode);
        uint256 initialStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );

        PIN.approve(address(stakingManager), stakeAmount);

        stakingManager.stake(stakeAmount);

        uint256 finalPINBalance = PIN.balanceOf(computeNode);
        uint256 finalStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );

        assertEq(
            finalPINBalance,
            initialPINBalance - stakeAmount,
            "PIN balance should decrease by staked amount"
        );

        // check if the staked balance increased by staked amount
        assertEq(
            finalStakedBalance,
            initialStakedBalance + stakeAmount,
            "Staked balance should increase by staked amount"
        );

        assertTrue(
            stakeAmount > stakingManager.MIN_DEPOSIT(),
            "Staked amount should be greater than minimum deposit"
        );

        assertEq(
            PIN.balanceOf(address(stakingManager)),
            stakeAmount,
            "StakingManager balance should match staked amount"
        );

        vm.stopPrank();

        vm.startPrank(computeNode);
        uint256 lowStakeAmount = stakingManager.MIN_DEPOSIT() - 1;
        PIN.approve(address(stakingManager), lowStakeAmount);
        vm.expectRevert("Deposit amount must be greater than minimum deposit");
        stakingManager.stake(lowStakeAmount);
        vm.stopPrank();  
        
    }

    function test_withdraw() public {
        uint256 stakeAmount = MIN_DEPOSIT + 1000 * 10 ** 18; // min deposit + 1000 tokens

        vm.startPrank(computeNode);

        PIN.approve(address(stakingManager), stakeAmount);
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
            "PIN balance should decrease by withdraw amount"
        );

        vm.stopPrank();
    }
}
