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
    uint256 public constant MIN_DEPOSIT = 10000 * 10 ** 18; // 1000 tokens

    function setUp() public {
        vm.startPrank(admin);

        PIN = new PrimeIntellectToken("Prime-Intellect-Token", "PIN");
        console.log("PrimeIntellectToken deployed at:", address(PIN));

        trainingManager = new TrainingManager();
        console.log("TrainingManager deployed at:", address(trainingManager));

        stakingManager = new StakingManager(
            address(PIN),
            address(trainingManager),
            admin
        );
        console.log("StakingManager deployed at:", address(stakingManager));

        PIN.grantRole(PIN.DEFAULT_ADMIN_ROLE(), admin);
        console.log("Minter role granted to admin");

        PIN.mint(computeNode, INITIAL_SUPPLY);
        console.log("Initial supply minted to compute node");

        trainingManager.addComputeNode(computeNode);
        console.log("Compute node registered in TrainingManager");

        vm.stopPrank();
        console.log("setUp completed successfully");
    }

    function test_stake() public {
        uint256 stakeAmount = MIN_DEPOSIT + 1;

        vm.startPrank(computeNode);

        uint256 initialPINBalance = PIN.balanceOf(computeNode);
        uint256 initialStakedBalance = stakingManager.getComputeNodeBalance(
            computeNode
        );

        PIN.approve(address(stakingManager), stakeAmount);

        stakingManager.stake(computeNode, stakeAmount);

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
        stakingManager.stake(computeNode, lowStakeAmount);
        vm.stopPrank();

        console.log("Staking test passed successfully");
        console.log("Initial PIN balance:", initialPINBalance);
        console.log("Staked amount:", stakeAmount);
        console.log("Final PIN balance:", finalPINBalance);
        console.log("Final staked balance:", finalStakedBalance);
    }
}
//         uint256 depositAmount = 2000 * 10 ** 18; // 2000 tokens

//         // Approve the StakingManager to spend user's tokens
//         vm.startPrank(user);
//         PIN.approve(address(staking), depositAmount);

//         // Check initial balances
//         uint256 initialUserBalance = PIN.balanceOf(user);
//         uint256 initialContractBalance = PIN.balanceOf(address(staking));

//         // Perform deposit
//         staking.deposit(depositAmount);

//         // Check final balances
//         uint256 finalUserBalance = PIN.balanceOf(user);
//         uint256 finalContractBalance = PIN.balanceOf(address(staking));

//         // Verify balances
//         assertEq(
//             finalUserBalance,
//             initialUserBalance - depositAmount,
//             "User balance should decrease by deposit amount"
//         );
//         assertEq(
//             finalContractBalance,
//             initialContractBalance + depositAmount,
//             "Contract balance should increase by deposit amount"
//         );

//         // Verify ComputeNodeInfo
//         (uint256 unspentBalance, , ) = staking.computeNodeBalances(user);
//         assertEq(
//             unspentBalance,
//             depositAmount,
//             "Unspent balance should equal deposit amount"
//         );

//         vm.stopPrank();
//     }

//     function testDepositBelowMinimum() public {
//         uint256 depositAmount = 500 * 10 ** 18; // 500 tokens, below MIN_DEPOSIT

//         vm.startPrank(user);
//         PIN.approve(address(staking), depositAmount);

//         // Expect revert when depositing below minimum
//         vm.expectRevert(
//             "Deposit amount must be greater than or equal to minimum deposit"
//         );
//         staking.deposit(depositAmount);

//         vm.stopPrank();
//     }

//     function testDepositUnregisteredUser() public {
//         address unregisteredUser = address(0x2);
//         uint256 depositAmount = 2000 * 10 ** 18;

//         PIN.transfer(unregisteredUser, depositAmount);

//         vm.startPrank(unregisteredUser);
//         PIN.approve(address(staking), depositAmount);

//         // Expect revert when unregistered user tries to deposit
//         vm.expectRevert("Account not on Compute Node whitelist");
//         staking.deposit(depositAmount);

//         vm.stopPrank();
//     }

//     function testDepositInsufficientBalance() public {
//         uint256 depositAmount = 20000 * 10 ** 18; // More than user's balance

//         vm.startPrank(user);
//         PIN.approve(address(staking), depositAmount);

//         // Expect revert when user has insufficient balance
//         vm.expectRevert("ERC20: transfer amount exceeds balance");
//         staking.deposit(depositAmount);

//         vm.stopPrank();
//     }

//     function testMultipleDeposits() public {
//         uint256 firstDeposit = 2000 * 10 ** 18;
//         uint256 secondDeposit = 3000 * 10 ** 18;

//         vm.startPrank(user);
//         PIN.approve(address(staking), firstDeposit + secondDeposit);

//         // First deposit
//         staking.deposit(firstDeposit);

//         // Second deposit
//         staking.deposit(secondDeposit);

//         // Verify ComputeNodeInfo
//         (uint256 unspentBalance, , ) = staking.computeNodeBalances(user);
//         assertEq(
//             unspentBalance,
//             firstDeposit + secondDeposit,
//             "Unspent balance should equal sum of deposits"
//         );

//         vm.stopPrank();
//     }
// }

// // function testStake() public {
// //     uint256 stakeAmount = 5000 * 10 ** 18; // 5,000 tokens

// //     vm.startPrank(user);

// //     token.approve(address(manager), stakeAmount);

// //     uint256 initialUserBalance = token.balanceOf(user);
// //     uint256 initialManagerBalance = token.balanceOf(address(manager));
// //     uint256 initialStakedBalance = manager.stakedBalance(user);
// //     uint256 initialTotalStaked = manager.totalStaked();

// //     manager.stake(stakeAmount);

// //     uint256 finalUserBalance = token.balanceOf(user);
// //     uint256 finalManagerBalance = token.balanceOf(address(manager));
// //     uint256 finalStakedBalance = manager.stakedBalance(user);
// //     uint256 finalTotalStaked = manager.totalStaked();

// //     assertEq(
// //         finalUserBalance,
// //         initialUserBalance - stakeAmount,
// //         "User balance should decrease by stake amount"
// //     );
// //     assertEq(
// //         finalManagerBalance,
// //         initialManagerBalance + stakeAmount,
// //         "Manager balance should increase by stake amount"
// //     );
// //     assertEq(
// //         finalStakedBalance,
// //         initialStakedBalance + stakeAmount,
// //         "Staked balance should increase by stake amount"
// //     );
// //     assertEq(
// //         finalTotalStaked,
// //         initialTotalStaked + stakeAmount,
// //         "Total staked should increase by stake amount"
// //     );

// //     vm.stopPrank();
// // }

// // function testStakeInsufficientBalance() public {
// //     uint256 userBalance = 1000 * 10 ** 18;
// //     uint256 stakeAmount = userBalance + 1 * 10 ** 18;

// //     vm.startPrank(owner);
// //     token.mint(user, userBalance);
// //     vm.stopPrank();

// //     vm.startPrank(user);
// //     token.approve(address(manager), stakeAmount);

// //     vm.expectRevert("ERC20: transfer amount exceeds balance");
// //     manager.stake(stakeAmount);

// //     vm.stopPrank();

// //     assertEq(
// //         token.balanceOf(user),
// //         userBalance,
// //         "User balance should not change"
// //     );
// //     assertEq(
// //         manager.totalStaked(),
// //         0,
// //         "Total staked amount should not change"
// //     );
// //     assertEq(
// //         manager.stakedBalance(user),
// //         0,
// //         "User staked balance should not change"
// //     );
// // }

// // function testStakeZeroAmount() public {
// //     vm.startPrank(user);
// //     vm.expectRevert("Amount must be greater than 0");
// //     manager.stake(0);
// //     vm.stopPrank();
// // }
