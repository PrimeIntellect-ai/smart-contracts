// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RewardsDistributorWorkSubmission.sol";
import "../src/interfaces/IComputePool.sol";
import "../src/interfaces/IComputeRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/interfaces/IRewardsDistributor.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockComputePool {
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE");
    bytes32 public constant FEDERATOR_ROLE = keccak256("FEDERATOR_ROLE");

    address public rewardToken;
    IRewardsDistributor public distributor;
    MockComputeRegistry public computeRegistry;
    mapping(address => bool) public nodes;
    uint256 public poolId;
    uint256 public totalCompute;

    constructor(address _rewardToken, uint256 _poolId, MockComputeRegistry _computeRegistry) {
        rewardToken = _rewardToken;
        poolId = _poolId;
        computeRegistry = _computeRegistry;
    }

    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    function getRoleMember(bytes32 role, uint256 /*index*/ ) external view returns (address) {
        // For simplicity, return this contract if PRIME_ROLE or FEDERATOR_ROLE
        if (role == PRIME_ROLE || role == FEDERATOR_ROLE) {
            return address(this);
        }
        // else
        return address(0);
    }

    function isNodeInPool(uint256 _poolId, address node) external view returns (bool) {
        require(_poolId == poolId, "Wrong poolId");
        return nodes[node];
    }

    function joinComputePool(address node, uint256 cu) external {
        if (nodes[node]) {
            revert("Node already active");
        }
        nodes[node] = true;
        computeRegistry.setNodeComputeUnits(node, cu);
        distributor.joinPool(node);
        totalCompute += cu;
    }

    function leaveComputePool(address node) external {
        require(nodes[node], "Node not active");
        nodes[node] = false;
        distributor.leavePool(node);
        totalCompute -= computeRegistry.getNodeComputeUnits(node);
    }

    function setDistributorContract(IRewardsDistributor _distributor) external {
        distributor = _distributor;
    }

    function getComputePoolTotalCompute(uint256 _poolId) external view returns (uint256) {
        require(_poolId == poolId, "Wrong poolId");
        return totalCompute;
    }
}

contract MockComputeRegistry {
    mapping(address => address) public nodeProviderMap;
    mapping(address => uint256) public nodeComputeUnits;

    function setNodeProvider(address node, address provider) external {
        nodeProviderMap[node] = provider;
    }

    function getNodeProvider(address node) external view returns (address) {
        return nodeProviderMap[node];
    }

    function setNodeComputeUnits(address node, uint256 cu) external {
        nodeComputeUnits[node] = cu;
    }

    function getNodeComputeUnits(address node) external view returns (uint256) {
        return nodeComputeUnits[node];
    }
}

contract RewardsDistributorWorkSubmissionRingBufferTest is Test {
    // Contracts
    RewardsDistributorWorkSubmission public distributor;
    MockComputePool public mockComputePool;
    MockComputeRegistry public mockComputeRegistry;
    MockERC20 public mockRewardToken;

    // Test addresses
    address public manager = address(0x1); // granted REWARDS_MANAGER_ROLE
    address public computePoolAddress = address(0x2);
    address public nodeProvider = address(0x3);
    address public node = address(0x4);

    // Additional nodes/providers
    address public node1 = address(0x5);
    address public node2 = address(0x6);
    address public nodeProvider1 = address(0x7);
    address public nodeProvider2 = address(0x8);

    // Helper: Ring buffer settings from the distributor
    // Adjust if you changed them in the ring-buffer contract
    uint256 public constant NUM_BUCKETS = 24;
    uint256 public constant BUCKET_DURATION = 3600; // 1 hour

    function fetchRewards(address _node, bool b) public view returns (uint256) {
        (uint256 claimable, uint256 locked) = distributor.calculateRewards(_node);
        if (b == false) {
            return claimable;
        } else {
            return locked;
        }
    }

    function setUp() public {
        // Deploy and mint tokens
        mockRewardToken = new MockERC20("MockToken", "MTK");
        mockRewardToken.mint(address(this), 1_000_000 ether);

        // Setup mocks
        mockComputeRegistry = new MockComputeRegistry();
        mockComputePool = new MockComputePool(address(mockRewardToken), 1, mockComputeRegistry);

        // Deploy the ring-buffer version
        distributor = new RewardsDistributorWorkSubmission(
            IComputePool(address(mockComputePool)), IComputeRegistry(address(mockComputeRegistry)), 1
        );

        // Grant roles
        distributor.grantRole(distributor.REWARDS_MANAGER_ROLE(), manager);

        // Transfer tokens to the distributor so it can pay out claims
        mockRewardToken.transfer(address(distributor), 500_000 ether);

        // Setup registry mappings
        mockComputeRegistry.setNodeProvider(node, nodeProvider);
        mockComputeRegistry.setNodeProvider(node1, nodeProvider1);
        mockComputeRegistry.setNodeProvider(node2, nodeProvider2);

        // Link the distributor to the pool
        mockComputePool.setDistributorContract(distributor);

        vm.prank(manager);
        distributor.setRewardRate(1); // Set a reward rate for testing
    }

    // -----------------------------------------------------------------------
    // Test: joinPool
    // -----------------------------------------------------------------------
    function testJoinPool() public {
        (uint256 last24H, uint256 totalAll,, bool isActive) = distributor.nodeInfo(node);
        assertEq(last24H, 0);
        assertEq(totalAll, 0);
        assertFalse(isActive);

        // Join the pool
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // After join
        (last24H, totalAll,, isActive) = distributor.nodeInfo(node);
        assertEq(last24H, 0);
        assertEq(totalAll, 0);
        assertTrue(isActive);

        // Attempt to join again should revert
        vm.expectRevert("Node already active");
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);
    }

    // -----------------------------------------------------------------------
    // Test: submitWork & ring buffer basics
    // -----------------------------------------------------------------------
    function testSubmitWorkAndLocking() public {
        // Join with 10 CU, though "CU" isn't directly used for ring buffer anymore.
        // (The ring buffer logic just sums submissions. You can still track CU if desired.)
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Initially, node's ring buffer is empty
        (uint256 last24H, uint256 totalAll,,) = distributor.nodeInfo(node);
        assertEq(last24H, 0);
        assertEq(totalAll, 0);

        // Submit some work
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 1000);

        // Now totalLast24H = 1000, totalAllSubmissions = 1000
        (last24H, totalAll,,) = distributor.nodeInfo(node);
        assertEq(last24H, 1000);
        assertEq(totalAll, 1000);

        // The ring buffer locks the last 24h, so if we claim now, we get 0 (all locked).
        uint256 calcBefore = fetchRewards(node, false);
        assertEq(calcBefore, 0, "Should be zero because it's < 24h old");

        // Move forward 12 hours
        skip(12 hours);
        // The 1000 is still within 24h, so locked
        assertEq(fetchRewards(node, false), 0);

        // Move forward another 13 hours (total 25h)
        // That should push the first 1000 submission outside the 24h window
        skip(13 hours);
        // Now it's been 25h, so the 1000 is fully unlocked.
        // The ring buffer automatically resets that bucket on the next call or view.
        uint256 calcAfter = fetchRewards(node, false);
        // We expect 1000 unlocked
        assertEq(calcAfter, 1000);

        // Claim should pay out the 1000
        vm.prank(nodeProvider);
        distributor.claimRewards(node);
        (,, uint256 lastClaimed,) = distributor.nodeInfo(node);
        assertEq(lastClaimed, 1000, "lastClaimed should be 1000 now");

        // The node receives the tokens
        assertEq(mockRewardToken.balanceOf(nodeProvider), 1000, "node's token balance mismatch");
    }

    // -----------------------------------------------------------------------
    // Test: multiple submissions within 24h
    // -----------------------------------------------------------------------
    function testMultipleSubmissionsWithin24h() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Submit 1000 at t=0
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 1000);

        // Skip 2 hours, submit another 500
        skip(2 hours);
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 500);

        // Both submissions are within 24h => locked
        uint256 unlocked = fetchRewards(node, false);
        assertEq(unlocked, 0, "All should be locked still (24h not passed)");

        // Skip 23 more hours => total 25h from the first submission, 23h from the second
        skip(23 hours);
        // Now the first 1000 is older than 24h => unlocked
        // The second 500 is at 25-2=23h old => still locked
        unlocked = fetchRewards(node, false);
        assertEq(unlocked, 1000, "First submission unlocked, second still locked");

        // Claim
        vm.prank(nodeProvider);
        distributor.claimRewards(node);
        assertEq(mockRewardToken.balanceOf(nodeProvider), 1000);

        // Skip 2 more hours => total 25h from the second submission
        skip(2 hours);
        // Now the 500 is also older than 24h => unlocked
        unlocked = fetchRewards(node, false);
        assertEq(unlocked, 500);

        vm.prank(nodeProvider);
        distributor.claimRewards(node);
        assertEq(mockRewardToken.balanceOf(nodeProvider), 1500);
    }

    // -----------------------------------------------------------------------
    // Test: large skip that resets ring buffer
    // -----------------------------------------------------------------------
    function testResetRingBuffer() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 1000);

        // Immediately skip more than 24 hours => entire ring buffer is stale
        skip(2 days); // 48 hours

        // The ring buffer will be fully reset for that node upon next submission or roll
        // So the old 1000 is definitely unlocked
        uint256 unlocked = fetchRewards(node, false);
        assertEq(unlocked, 1000);

        vm.prank(nodeProvider);
        distributor.claimRewards(node);
        assertEq(mockRewardToken.balanceOf(nodeProvider), 1000);

        // Submit again
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 500);

        (uint256 last24H, uint256 totalAll,,) = distributor.nodeInfo(node);
        // Last 24h is 500, totalAll is 1500
        assertEq(last24H, 500);
        assertEq(totalAll, 1500);
    }

    // -----------------------------------------------------------------------
    // Test: multiple nodes
    // -----------------------------------------------------------------------
    function testMultipleNodes() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);

        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 5);

        // Node1 submits 200
        vm.prank(address(mockComputePool));
        distributor.submitWork(node1, 200);

        // Node2 submits 300
        vm.prank(address(mockComputePool));
        distributor.submitWork(node2, 300);

        // Both are <24h => locked, no one gets anything if we claim
        assertEq(fetchRewards(node1, false), 0);
        assertEq(fetchRewards(node2, false), 0);

        skip(25 hours);
        // Now both are fully unlocked
        uint256 node1Unlocked = fetchRewards(node1, false);
        uint256 node2Unlocked = fetchRewards(node2, false);

        assertEq(node1Unlocked, 200);
        assertEq(node2Unlocked, 300);

        vm.prank(nodeProvider1);
        distributor.claimRewards(node1);
        vm.prank(nodeProvider2);
        distributor.claimRewards(node2);

        assertEq(mockRewardToken.balanceOf(nodeProvider1), 200);
        assertEq(mockRewardToken.balanceOf(nodeProvider2), 300);
    }

    // -----------------------------------------------------------------------
    // Test: partial locked/unlocked for multiple nodes
    // -----------------------------------------------------------------------
    function testPartialLockMultipleNodes() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 5);

        // Node1 submits 100 at t=0
        vm.prank(address(mockComputePool));
        distributor.submitWork(node1, 100);

        // Node2 submits 50 at t=0
        vm.prank(address(mockComputePool));
        distributor.submitWork(node2, 50);

        // Skip 12h
        skip(12 hours);
        // Node1 submits another 100 at t=12h
        vm.prank(address(mockComputePool));
        distributor.submitWork(node1, 100);

        // Node2 has no new submissions
        // Skip another 13h => total t=25h from first submission
        skip(13 hours);

        // At t=25h:
        // Node1's first 100 is unlocked, second 100 is 13h old => locked
        // Node2's 50 is 25h old => unlocked
        uint256 node1Unlocked = fetchRewards(node1, false);
        uint256 node2Unlocked = fetchRewards(node2, false);

        assertEq(node1Unlocked, 100, "Node1 only the first 100 is unlocked");
        assertEq(node2Unlocked, 50, "Node2's entire 50 is unlocked");

        // Claim for both
        vm.prank(nodeProvider1);
        distributor.claimRewards(node1);
        vm.prank(nodeProvider2);
        distributor.claimRewards(node2);

        assertEq(mockRewardToken.balanceOf(nodeProvider1), 100);
        assertEq(mockRewardToken.balanceOf(nodeProvider2), 50);

        // Move ahead another 12 hours => t=37h from the second submission for Node1
        skip(12 hours);

        // Now Node1's second 100 is also >24h => unlocked
        node1Unlocked = fetchRewards(node1, false);
        assertEq(node1Unlocked, 100);

        vm.prank(nodeProvider1);
        distributor.claimRewards(node1);
        assertEq(mockRewardToken.balanceOf(nodeProvider1), 200);
    }

    // -----------------------------------------------------------------------
    // Test: leavePool (no special logic, but ensures ring buffer not affected)
    // -----------------------------------------------------------------------
    function testLeavePool() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 500);

        (uint256 last24HBefore, uint256 totalAllBefore,, bool isActiveBefore) = distributor.nodeInfo(node);
        assertEq(last24HBefore, 500);
        assertEq(totalAllBefore, 500);
        assertTrue(isActiveBefore);

        vm.prank(address(mockComputePool));
        mockComputePool.leaveComputePool(node);

        (uint256 last24HAfter, uint256 totalAllAfter,, bool isActiveAfter) = distributor.nodeInfo(node);
        // The ring buffer data remains the same; isActive is false
        assertEq(last24HAfter, 500);
        assertEq(totalAllAfter, 500);
        assertFalse(isActiveAfter);

        // Move 25 hours => old data is unlocked
        skip(25 hours);
        uint256 unlocked = fetchRewards(node, false);
        assertEq(unlocked, 500);

        // Claim
        vm.prank(nodeProvider);
        distributor.claimRewards(node);
        assertEq(mockRewardToken.balanceOf(nodeProvider), 500);
    }

    // -----------------------------------------------------------------------
    // Test: slashPendingRewards
    // -----------------------------------------------------------------------
    function testSlashPendingRewards() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // 1) Node submits some work => last24H = 100
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 100);

        // Skip 25h so the 100 is unlocked. totalAll=100, last24H=100, but effectively 0 locked.
        skip(25 hours);

        // 2) Node submits more work => last24H = 200, totalAll=300
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 200);

        // Check ring-buffer state
        (uint256 last24HBefore,,, bool isActive) = distributor.nodeInfo(node);
        assertTrue(isActive);
        assertEq(
            last24HBefore,
            300 - 100,
            "Only the new 200 should be truly locked, but last24H tracks all submissions in <24h"
        );
        // Because we haven't done a "roll" on the now-unlocked 100 yet, last24H might read 300.
        // But the oldest 100 is older than 24h.
        // The .calculateRewards(...) should reflect 100 unlocked, 200 locked.

        // Confirm the actual "unlocked" portion is 100
        uint256 unlockedNow = fetchRewards(node, false);
        assertEq(unlockedNow, 100, "First 100 is unlocked, second 200 is locked.");

        // 3) Slash the node's pending 24h => manager only
        // That should remove the locked 200 from totalAll, zero the ring buffer, etc.
        vm.prank(manager);
        distributor.slashPendingRewards(node);

        // 4) After slash, the last24H and buckets are all zero. totalAll = 100 (the unlocked portion remains).
        (uint256 last24HAfter, uint256 totalAllAfter,,) = distributor.nodeInfo(node);
        assertEq(last24HAfter, 0, "Should have cleared the ring buffer");
        assertEq(totalAllAfter, 100, "Should have subtracted the slashed 200 from totalAll");
        // lastClaimed should remain the same, because we didn't claim.

        // 5) Confirm that now, if we skip 25 hours more, there is no "locked" portion to unlock
        skip(25 hours);
        uint256 unlockedAfterSlash = fetchRewards(node, false);
        // The 100 is still unlocked, but we never claimed it, so it remains unclaimed.
        // Because slash only subtracted from totalAll the "locked" portion, the older 100 is unaffected.
        // So unlockedAfterSlash == 100 - lastClaimedAfter. But we haven't claimed at all, so lastClaimedAfter=0.
        assertEq(unlockedAfterSlash, 100, "The older 100 remains claimable.");
    }

    // -----------------------------------------------------------------------
    // Test: Soft slash functionality - removeWork
    // -----------------------------------------------------------------------
    function testRemoveWork() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Submit some work
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 500);

        (uint256 last24HBefore, uint256 totalAllBefore,,) = distributor.nodeInfo(node);
        assertEq(last24HBefore, 500);
        assertEq(totalAllBefore, 500);

        // Remove 200 work units
        vm.prank(address(mockComputePool));
        distributor.removeWork(node, 200);

        (uint256 last24HAfter, uint256 totalAllAfter,,) = distributor.nodeInfo(node);
        assertEq(last24HAfter, 300, "Should have removed 200 work units");
        assertEq(totalAllAfter, 300, "Total submissions should also be reduced");
    }

    function testRemoveWorkExceedsAvailable() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Submit 100 work units
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 100);

        // Try to remove 200 (more than available)
        vm.prank(address(mockComputePool));
        distributor.removeWork(node, 200);

        // Should only remove what's available (100)
        (uint256 last24H, uint256 totalAll,,) = distributor.nodeInfo(node);
        assertEq(last24H, 0, "Should have removed all available work");
        assertEq(totalAll, 0, "Total should also be zero");
    }

    function testRemoveWorkAcrossMultipleBuckets() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Submit work in different time buckets
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 100);

        skip(2 hours); // Move to next bucket
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 200);

        skip(2 hours); // Move to next bucket
        vm.prank(address(mockComputePool));
        distributor.submitWork(node, 300);

        // Total should be 600
        (uint256 last24HBefore, uint256 totalAllBefore,,) = distributor.nodeInfo(node);
        assertEq(last24HBefore, 600);
        assertEq(totalAllBefore, 600);

        // Remove 450 work units (should span multiple buckets)
        vm.prank(address(mockComputePool));
        distributor.removeWork(node, 450);

        (uint256 last24HAfter, uint256 totalAllAfter,,) = distributor.nodeInfo(node);
        assertEq(last24HAfter, 150, "Should have removed 450 work units");
        assertEq(totalAllAfter, 150, "Total should also be reduced");
    }

    // -----------------------------------------------------------------------
    // Test: Your use case - multiple nodes (call multiple times)
    // -----------------------------------------------------------------------
    function testMultipleNodeRemoval() public {
        // Setup multiple nodes
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 10);

        // Submit work for both nodes
        vm.prank(address(mockComputePool));
        distributor.submitWork(node1, 100);
        vm.prank(address(mockComputePool));
        distributor.submitWork(node2, 150);

        // Remove work from both nodes (call multiple times)
        vm.prank(address(mockComputePool));
        distributor.removeWork(node1, 80);
        vm.prank(address(mockComputePool));
        distributor.removeWork(node2, 80);

        // Check results - both should have 80 removed
        (uint256 last24H1, uint256 totalAll1,,) = distributor.nodeInfo(node1);
        (uint256 last24H2, uint256 totalAll2,,) = distributor.nodeInfo(node2);

        assertEq(last24H1, 20, "Node1 should have 20 remaining (100-80)");
        assertEq(totalAll1, 20, "Node1 total should be 20");
        assertEq(last24H2, 70, "Node2 should have 70 remaining (150-80)");
        assertEq(totalAll2, 70, "Node2 total should be 70");
    }
}
