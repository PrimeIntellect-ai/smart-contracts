// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakeManager.sol";
import "../src/interfaces/IStakeManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*──────────────────────── Mocks ────────────────────────*/
contract MockERC20 is ERC20 {
    constructor() ERC20("AI Token", "AI") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/*─────────────────────── Test Suite ─────────────────────*/
contract StakeManagerTest is Test {
    /* roles & addresses */
    address internal prime = address(this); // gets PRIME + DEFAULT_ADMIN in ctor
    address internal staker = address(0xBEEF);
    bytes32 constant PRIME_ROLE = keccak256("PRIME_ROLE");

    /* system under test */
    MockERC20 internal token;
    StakeManager internal mgr;

    /* constants */
    uint256 constant PERIOD = 7 days;
    uint256 constant ONE = 1 ether;
    uint256 constant HUND = 100 * ONE;

    /*────────── Setup ─────────*/
    function setUp() public {
        token = new MockERC20();
        mgr = new StakeManager(prime, PERIOD, IERC20(token));

        token.mint(prime, 1_000_000 * ONE);
        token.mint(staker, 1_000_000 * ONE);

        token.approve(address(mgr), type(uint256).max);
        vm.prank(staker);
        token.approve(address(mgr), type(uint256).max); // not strictly needed but convenient
    }

    /*────────── helpers ─────────*/
    function _stake(address who, uint256 amt) internal {
        vm.prank(prime);
        mgr.stake(who, amt);
    }

    function _unstake(address who, uint256 amt) internal {
        vm.prank(prime);
        mgr.unstake(who, amt);
    }

    /*────────── tests ─────────*/

    function testStakeIncreasesBalances() public {
        vm.expectEmit(true, false, false, true);
        emit Stake(staker, HUND);

        _stake(staker, HUND);

        assertEq(mgr.getStake(staker), HUND);
        assertEq(mgr.getTotalStaked(), HUND);
        assertEq(token.balanceOf(address(mgr)), HUND);
        assertEq(token.balanceOf(prime), 1_000_000 * ONE - HUND);
    }

    function testStakeRequiresPrime() public {
        vm.prank(staker);
        vm.expectRevert(); // AccessControl
        mgr.stake(staker, ONE);
    }

    function testUnstakeMovesToPending() public {
        _stake(staker, HUND);

        vm.expectEmit(true, false, false, true);
        emit Unstake(staker, 40 * ONE);

        _unstake(staker, 40 * ONE);

        assertEq(mgr.getStake(staker), 60 * ONE);
        assertEq(mgr.getPendingUnbondTotal(staker), 40 * ONE);

        StakeManager.Unbond[] memory arr = mgr.getPendingUnbonds(staker);
        assertEq(arr.length, 1);
        assertEq(arr[0].amount, 40 * ONE);
        assertEq(arr[0].timestamp, block.timestamp + PERIOD);
    }

    function testWithdrawAfterPeriod() public {
        _stake(staker, HUND);
        _unstake(staker, HUND);

        vm.warp(block.timestamp + PERIOD + 1);

        uint256 balBefore = token.balanceOf(staker);

        vm.prank(staker);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(staker, HUND);
        mgr.withdraw();

        assertEq(token.balanceOf(staker), balBefore + HUND);
        assertEq(mgr.getPendingUnbondTotal(staker), 0);
        assertEq(mgr.getTotalUnbonding(), 0);
    }

    function testWithdrawRevertsIfNothing() public {
        vm.prank(staker);
        vm.expectRevert(bytes("StakeManager: no funds to withdraw"));
        mgr.withdraw();
    }

    function testRebondPartial() public {
        _stake(staker, HUND);
        _unstake(staker, HUND);

        vm.expectEmit(true, false, false, true);
        emit Rebond(staker, 40 * ONE);

        vm.prank(prime);
        mgr.rebond(staker, 40 * ONE);

        assertEq(mgr.getStake(staker), 40 * ONE + 0); // 40 rebonded on top of 0 residual
        assertEq(mgr.getPendingUnbondTotal(staker), 60 * ONE);
        StakeManager.Unbond[] memory arr = mgr.getPendingUnbonds(staker);
        // first slot reduced by 40
        assertEq(arr[0].amount, 60 * ONE);
    }

    function testRebondFull() public {
        _stake(staker, HUND);
        _unstake(staker, HUND);

        vm.expectEmit(true, false, false, true);
        emit Rebond(staker, 100 * ONE);

        vm.prank(prime);
        mgr.rebond(staker, 100 * ONE);

        assertEq(mgr.getStake(staker), 100 * ONE);
        assertEq(mgr.getPendingUnbondTotal(staker), 0);
        StakeManager.Unbond[] memory arr = mgr.getPendingUnbonds(staker);
        assertEq(arr.length, 0); // all unbonds rebonded
    }

    function testMaxPendingAggregates() public {
        _stake(staker, 1000 * ONE);

        // create 10 unbonds
        for (uint256 i; i < 9; i++) {
            _unstake(staker, ONE);
        } // first 9 individual
        _unstake(staker, ONE); // 10th — separate slot
        // next call should aggregate into the 10th
        _unstake(staker, ONE);

        StakeManager.Unbond[] memory arr = mgr.getPendingUnbonds(staker);
        assertEq(arr.length, 10);
        assertEq(arr[9].amount, 2 * ONE); // aggregated
    }

    function testSlashFromStake() public {
        _stake(staker, HUND);

        vm.expectEmit(true, false, false, true);
        emit Slashed(staker, 30 * ONE, "");

        vm.prank(prime);
        uint256 slashed = mgr.slash(staker, 30 * ONE, "");

        assertEq(slashed, 30 * ONE);
        assertEq(mgr.getStake(staker), 70 * ONE);
        assertEq(token.balanceOf(prime), 1_000_000 * ONE - HUND + 30 * ONE);
    }

    function testSlashPrefersUnbonding() public {
        _stake(staker, HUND);
        _unstake(staker, HUND); // entire stake now pending

        vm.prank(prime);
        uint256 slashed = mgr.slash(staker, 60 * ONE, "");

        assertEq(slashed, 60 * ONE);
        assertEq(mgr.getPendingUnbondTotal(staker), 40 * ONE);
        assertEq(mgr.getTotalUnbonding(), 40 * ONE);
    }

    function testSettersRequirePrime() public {
        vm.prank(staker);
        vm.expectRevert(); // AccessControl
        mgr.setUnbondingPeriod(1 days);

        vm.prank(prime);
        mgr.setUnbondingPeriod(1 days);
        assertEq(mgr.getUnbondingPeriod(), 1 days);

        vm.prank(staker);
        vm.expectRevert();
        mgr.setStakeMinimum(10 * ONE);

        vm.prank(prime);
        mgr.setStakeMinimum(10 * ONE);
        assertEq(mgr.getStakeMinimum(), 10 * ONE);
    }
}
