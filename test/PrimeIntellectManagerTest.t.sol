// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PrimeIntellectManager} from "../src/PrimeIntellectManager.sol";
import {PrimeIntellectToken} from "../src/PrimeIntellectToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PrimeIntellectManagerTest is Test {
    PrimeIntellectManager public manager;
    PrimeIntellectToken public token;
    address public owner;
    address public user;
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18; // 1 million tokens
    uint256 public constant MIN_STAKE = 1000 * 10 ** 18; // 1000 tokens
    string public constant TOKEN_NAME = "PrimeIntellect";
    string public constant TOKEN_SYMBOL = "PIT";

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        // Deploy the token
        token = new PrimeIntellectToken(TOKEN_NAME, TOKEN_SYMBOL);

        // Deploy the manager
        manager = new PrimeIntellectManager(
            IERC20(address(token)),
            owner,
            MIN_STAKE
        );

        token.mint(address(this), INITIAL_SUPPLY);
        token.transfer(user, 10000 * 10 ** 18); // 10,000 tokens
    }

    function testStake() public {
        uint256 stakeAmount = 5000 * 10 ** 18; // 5,000 tokens

        vm.startPrank(user);

        token.approve(address(manager), stakeAmount);

        uint256 initialUserBalance = token.balanceOf(user);
        uint256 initialManagerBalance = token.balanceOf(address(manager));
        uint256 initialStakedBalance = manager.stakedBalance(user);
        uint256 initialTotalStaked = manager.totalStaked();

        manager.stake(stakeAmount);

        uint256 finalUserBalance = token.balanceOf(user);
        uint256 finalManagerBalance = token.balanceOf(address(manager));
        uint256 finalStakedBalance = manager.stakedBalance(user);
        uint256 finalTotalStaked = manager.totalStaked();

        assertEq(
            finalUserBalance,
            initialUserBalance - stakeAmount,
            "User balance should decrease by stake amount"
        );
        assertEq(
            finalManagerBalance,
            initialManagerBalance + stakeAmount,
            "Manager balance should increase by stake amount"
        );
        assertEq(
            finalStakedBalance,
            initialStakedBalance + stakeAmount,
            "Staked balance should increase by stake amount"
        );
        assertEq(
            finalTotalStaked,
            initialTotalStaked + stakeAmount,
            "Total staked should increase by stake amount"
        );

        vm.stopPrank();
    }

    function testStakeInsufficientBalance() public {
        uint256 userBalance = 1000 * 10 ** 18;
        uint256 stakeAmount = userBalance + 1 * 10 ** 18;

        vm.startPrank(owner);
        token.mint(user, userBalance);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(manager), stakeAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        manager.stake(stakeAmount);

        vm.stopPrank();

        assertEq(
            token.balanceOf(user),
            userBalance,
            "User balance should not change"
        );
        assertEq(
            manager.totalStaked(),
            0,
            "Total staked amount should not change"
        );
        assertEq(
            manager.stakedBalance(user),
            0,
            "User staked balance should not change"
        );
    }

    function testStakeZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert("Amount must be greater than 0");
        manager.stake(0);
        vm.stopPrank();
    }
}
