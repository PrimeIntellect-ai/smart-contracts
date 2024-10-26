// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/ITrainingManager.sol";

/// @notice Test to illustrate end to end process for a training run.

contract EndToEndTest is Test {
    StakingManager public stakingManager;
    TrainingManager public trainingManager;
    PrimeIntellectToken public PI;

    // create our users
    address public admin = address(1);
    address public computeNode = address(2);
    address public computeNode2 = address(3);
    address public computeNode3 = address(4);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);

        // deploy token contract
        PI = new PrimeIntellectToken("Prime Intellect Token", "PI");
        // deploy training manager
        trainingManager = new TrainingManager();
        // deploy staking manager
        stakingManager = new StakingManager(
            address(PI),
            address(trainingManager)
        );

        // inform training manager of staking manager's deployed address
        // this allows us to avoid circular dependency during deployment process
        trainingManager.setStakingManager(address(stakingManager));

        // issue tokens to our compute nodes
        // admin has minter role by default
        PI.mint(computeNode, INITIAL_SUPPLY);
        PI.mint(computeNode2, INITIAL_SUPPLY);
        PI.mint(computeNode3, INITIAL_SUPPLY);
        vm.stopPrank();
    }

    /// One run with multiple compute nodes earning rewards
    function testE2EBaseCase() public {
        vm.startPrank(admin);
        uint256 minStake = stakingManager.MIN_DEPOSIT();

        // add our compute nodes to whitelist
        trainingManager.whitelistComputeNode(computeNode);
        trainingManager.whitelistComputeNode(computeNode2);
        trainingManager.whitelistComputeNode(computeNode3);
        vm.stopPrank();

        // first compute node stakes
        vm.startPrank(computeNode);
        PI.approve(address(stakingManager), minStake);
        stakingManager.stake(minStake);

        assertEq(
            minStake,
            stakingManager.getComputeNodeBalance(computeNode),
            "INITAL_SUPPLY less staked amount equals balance"
        );
        vm.stopPrank();
    }
}
