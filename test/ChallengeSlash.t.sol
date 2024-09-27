// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/PrimeIntellectToken.sol";
import "../src/TrainingManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ChallengeSlash is Test {
    StakingManager public stakingManager;
    TrainingManager public trainingManager;
    PrimeIntellectToken public pinToken;

    address public admin = address(1);
    address public computeNode = address(2);

    uint256 public constant TRAINING_RUN_ID = 1;
    uint256 public constant ATTESTATION_COUNT = 10;

    function setUp() public {}

    function test_challenge() public {}
}
