// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Test to illustrate end to end process for a training run.

contract EndToEndTest is Test {
    StakingManager public stakingManager;
    TrainingManager public trainingManager;
    PrimeIntellectToken public PIN;

    address public admin = address(1);
    address public computeNode = address(2);
    address public computeNode2 = address(3);
    address public computeNode3 = address(4);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant MIN_DEPOSIT = 10000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);

        PIN = new PrimeIntellectToken("Prime Intellect Token", "PIN");
        trainingManager = new TrainingManager();
        stakingManager = new StakingManager(address(PIN), address(trainingManager));

        trainingManager.setStakingManager(address(stakingManager));

        PIN.mint(computeNode, INITIAL_SUPPLY);
        trainingManager.addComputeNode(computeNode);
        vm.stopPrank();
    }

    /// One run with multiple compute nodes earning rewards
    function E2ETestBaseCase() public {}
}
