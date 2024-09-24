// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";

contract StakingManagerTest is Test {
    StakingManager public staking;
    TrainingManager public training;
    PrimeIntellectToken public PIN;
    address public admin;
    address public user;
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18; // 1 million tokens
    uint256 public constant MIN_DEPOSIT = 1000 * 10 ** 18; // 1000 tokens
    string public constant TOKEN_NAME = "Prime-Intellect-Network-Token";
    string public constant TOKEN_SYMBOL = "PIN";

    function setUp() public {
        admin = address(this);
        user = address(0x1);

        // Deploy the token
        PIN = new PrimeIntellectToken(TOKEN_NAME, TOKEN_SYMBOL);

        training = new TrainingManager("NAME", 100);

        // Deploy the Network Manager
        staking = new StakingManager(IERC20(address(PIN)), admin);

        PIN.mint(address(this), INITIAL_SUPPLY);
        PIN.transfer(user, 10000 * 10 ** 18); // 10,000 tokens

        training.addComputeNode(user);
    }

    function testDeposit() public {
        uint256 depositAmount = 2000 * 10 ** 18; // 2000 tokens

        // Approve the StakingManager to spend user's tokens
        vm.startPrank(user);
        PIN.approve(address(staking), depositAmount);

        // Check initial balances
        uint256 initialUserBalance = PIN.balanceOf(user);
        uint256 initialContractBalance = PIN.balanceOf(address(staking));

        // Perform deposit
        staking.deposit(depositAmount);

        // Check final balances
        uint256 finalUserBalance = PIN.balanceOf(user);
        uint256 finalContractBalance = PIN.balanceOf(address(staking));

        // Verify balances
        assertEq(
            finalUserBalance,
            initialUserBalance - depositAmount,
            "User balance should decrease by deposit amount"
        );
        assertEq(
            finalContractBalance,
            initialContractBalance + depositAmount,
            "Contract balance should increase by deposit amount"
        );

        // Verify ComputeNodeInfo
        (uint256 unspentBalance, , ) = staking.computeNodeBalances(user);
        assertEq(
            unspentBalance,
            depositAmount,
            "Unspent balance should equal deposit amount"
        );

        vm.stopPrank();
    }

    function testDepositBelowMinimum() public {
        uint256 depositAmount = 500 * 10 ** 18; // 500 tokens, below MIN_DEPOSIT

        vm.startPrank(user);
        PIN.approve(address(staking), depositAmount);

        // Expect revert when depositing below minimum
        vm.expectRevert(
            "Deposit amount must be greater than or equal to minimum deposit"
        );
        staking.deposit(depositAmount);

        vm.stopPrank();
    }

    function testDepositUnregisteredUser() public {
        address unregisteredUser = address(0x2);
        uint256 depositAmount = 2000 * 10 ** 18;

        PIN.transfer(unregisteredUser, depositAmount);

        vm.startPrank(unregisteredUser);
        PIN.approve(address(staking), depositAmount);

        // Expect revert when unregistered user tries to deposit
        vm.expectRevert("Account not on Compute Node whitelist");
        staking.deposit(depositAmount);

        vm.stopPrank();
    }

    function testDepositInsufficientBalance() public {
        uint256 depositAmount = 20000 * 10 ** 18; // More than user's balance

        vm.startPrank(user);
        PIN.approve(address(staking), depositAmount);

        // Expect revert when user has insufficient balance
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        staking.deposit(depositAmount);

        vm.stopPrank();
    }

    function testMultipleDeposits() public {
        uint256 firstDeposit = 2000 * 10 ** 18;
        uint256 secondDeposit = 3000 * 10 ** 18;

        vm.startPrank(user);
        PIN.approve(address(staking), firstDeposit + secondDeposit);

        // First deposit
        staking.deposit(firstDeposit);

        // Second deposit
        staking.deposit(secondDeposit);

        // Verify ComputeNodeInfo
        (uint256 unspentBalance, , ) = staking.computeNodeBalances(user);
        assertEq(
            unspentBalance,
            firstDeposit + secondDeposit,
            "Unspent balance should equal sum of deposits"
        );

        vm.stopPrank();
    }
}

// function testStake() public {
//     uint256 stakeAmount = 5000 * 10 ** 18; // 5,000 tokens

//     vm.startPrank(user);

//     token.approve(address(manager), stakeAmount);

//     uint256 initialUserBalance = token.balanceOf(user);
//     uint256 initialManagerBalance = token.balanceOf(address(manager));
//     uint256 initialStakedBalance = manager.stakedBalance(user);
//     uint256 initialTotalStaked = manager.totalStaked();

//     manager.stake(stakeAmount);

//     uint256 finalUserBalance = token.balanceOf(user);
//     uint256 finalManagerBalance = token.balanceOf(address(manager));
//     uint256 finalStakedBalance = manager.stakedBalance(user);
//     uint256 finalTotalStaked = manager.totalStaked();

//     assertEq(
//         finalUserBalance,
//         initialUserBalance - stakeAmount,
//         "User balance should decrease by stake amount"
//     );
//     assertEq(
//         finalManagerBalance,
//         initialManagerBalance + stakeAmount,
//         "Manager balance should increase by stake amount"
//     );
//     assertEq(
//         finalStakedBalance,
//         initialStakedBalance + stakeAmount,
//         "Staked balance should increase by stake amount"
//     );
//     assertEq(
//         finalTotalStaked,
//         initialTotalStaked + stakeAmount,
//         "Total staked should increase by stake amount"
//     );

//     vm.stopPrank();
// }

// function testStakeInsufficientBalance() public {
//     uint256 userBalance = 1000 * 10 ** 18;
//     uint256 stakeAmount = userBalance + 1 * 10 ** 18;

//     vm.startPrank(owner);
//     token.mint(user, userBalance);
//     vm.stopPrank();

//     vm.startPrank(user);
//     token.approve(address(manager), stakeAmount);

//     vm.expectRevert("ERC20: transfer amount exceeds balance");
//     manager.stake(stakeAmount);

//     vm.stopPrank();

//     assertEq(
//         token.balanceOf(user),
//         userBalance,
//         "User balance should not change"
//     );
//     assertEq(
//         manager.totalStaked(),
//         0,
//         "Total staked amount should not change"
//     );
//     assertEq(
//         manager.stakedBalance(user),
//         0,
//         "User staked balance should not change"
//     );
// }

// function testStakeZeroAmount() public {
//     vm.startPrank(user);
//     vm.expectRevert("Amount must be greater than 0");
//     manager.stake(0);
//     vm.stopPrank();
// }
