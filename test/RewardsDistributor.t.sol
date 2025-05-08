// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RewardsDistributor.sol";
import "../src/interfaces/IComputePool.sol";
import "../src/interfaces/IComputeRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
    RewardsDistributor public distributor;
    MockComputeRegistry public computeRegistry;
    mapping(address => bool) public nodes;
    uint256 poolId;
    uint256 totalCompute;

    constructor(address _rewardToken, uint256 _poolId, MockComputeRegistry _computeRegistry) {
        rewardToken = _rewardToken;
        poolId = _poolId;
        computeRegistry = _computeRegistry;
    }

    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    // add getRoleMember mock as it's used in RewardsDistributor constructor
    function getRoleMember(bytes32 role, uint256 index) external view returns (address) {
        if (role == PRIME_ROLE) {
            return address(this);
        }
        if (role == FEDERATOR_ROLE) {
            return address(this);
        }
        index == index;
        return address(0);
    }

    function isNodeInPool(uint256 _poolId, address node) external view returns (bool) {
        poolId == _poolId;
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
        nodes[node] = false;
        distributor.leavePool(node);
        totalCompute -= computeRegistry.getNodeComputeUnits(node);
    }

    function setDistributorContract(RewardsDistributor _distributor) external {
        distributor = _distributor;
    }

    function getComputePoolTotalCompute(uint256 _poolId) external view returns (uint256) {
        _poolId == _poolId;
        return totalCompute;
    }

    // Add any additional mock functions if needed for your tests
}

contract MockComputeRegistry {
    // node => provider
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

    // Add any additional mock functions if needed for your tests
}

contract RewardsDistributorTest is Test {
    RewardsDistributor public distributor;
    MockComputePool public mockComputePool;
    MockComputeRegistry public mockComputeRegistry;
    MockERC20 public mockRewardToken;

    // Test addresses
    address public manager = address(0x1); // Has REWARDS_MANAGER_ROLE
    address public computePoolAddress = address(0x2); // Will hold COMPUTE_POOL_ROLE by default from constructor
    address public nodeProvider = address(0x3);
    address public node = address(0x4);

    // Additional nodes/providers
    address public node1 = address(0x5);
    address public node2 = address(0x6);
    address public nodeProvider1 = address(0x7);
    address public nodeProvider2 = address(0x8);

    function setUp() public {
        // 1. Deploy a mock token & mint an initial supply
        mockRewardToken = new MockERC20("MockToken", "MTK");
        mockRewardToken.mint(address(this), 1_000_000 ether); // Mint to ourselves for testing

        // 2. Deploy mocks for IComputePool & IComputeRegistry
        mockComputeRegistry = new MockComputeRegistry();
        mockComputePool = new MockComputePool(address(mockRewardToken), 1, mockComputeRegistry);

        // 3. Deploy the RewardsDistributor
        distributor = new RewardsDistributor(
            IComputePool(address(mockComputePool)),
            IComputeRegistry(address(mockComputeRegistry)),
            1 // poolId
        );

        // 4. By default, constructor grants COMPUTE_POOL_ROLE to the computePool
        //    but we need to re-grant it to our mockComputePool if addresses differ
        //    Because we used mockComputePool as the constructor arg, it's already set.
        //    If you want a different address to be recognized as the compute pool, you can do:
        // distributor.grantRole(distributor.COMPUTE_POOL_ROLE(), computePoolAddress);

        // 5. Give manager the REWARDS_MANAGER_ROLE
        distributor.grantRole(distributor.REWARDS_MANAGER_ROLE(), manager);

        // 6. Fund the distributor with the reward token so it can pay out
        mockRewardToken.transfer(address(distributor), 500_000 ether);

        // 7. Set up the node-provider relationship in the registry
        mockComputeRegistry.setNodeProvider(node, nodeProvider);
        mockComputeRegistry.setNodeProvider(node1, nodeProvider1);
        mockComputeRegistry.setNodeProvider(node2, nodeProvider2);

        // 8. Set distribute contract in mockComputePool
        mockComputePool.setDistributorContract(distributor);
    }

    /// ---------------------------------------
    /// Test: setRewardRate
    /// ---------------------------------------
    function testSetRewardRate() public {
        // Check initial reward rate is 0
        assertEq(distributor.rewardRatePerSecond(), 0);

        // Non-manager tries to set - should revert
        vm.prank(node);
        vm.expectRevert();
        distributor.setRewardRate(10);

        // Manager sets reward rate
        vm.prank(manager);
        distributor.setRewardRate(10);
        assertEq(distributor.rewardRatePerSecond(), 10);
    }

    /// ---------------------------------------
    /// Test: joinPool
    /// ---------------------------------------
    function testJoinPool() public {
        // Node not active initially
        (uint256 cu,,, bool isActive) = distributor.nodeInfo(node);
        assertEq(cu, 0);
        assertFalse(isActive);

        // Have the compute pool (with role) call joinPool
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Now node is active
        (cu,,, isActive) = distributor.nodeInfo(node);
        assertEq(cu, 10);
        assertTrue(isActive);

        // Trying to join again should revert since isActive is true
        vm.expectRevert("Node already active");
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);
    }

    /// ---------------------------------------
    /// Test: leavePool
    /// ---------------------------------------
    function testLeavePool() public {
        // Must join first
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Node is active
        (,,, bool isActive) = distributor.nodeInfo(node);
        assertTrue(isActive);

        // set reward rate
        vm.prank(manager);
        distributor.setRewardRate(1 ether);

        // Warp some time so there's a reward accrual
        vm.warp(block.timestamp + 100);

        // Now leave
        vm.prank(address(mockComputePool));
        mockComputePool.leaveComputePool(node);

        // Node is no longer active
        (,,, isActive) = distributor.nodeInfo(node);
        assertFalse(isActive);

        // Check that calculateRewards shows the same
        (uint256 calculatedRewards,) = distributor.calculateRewards(node);

        // The unclaimedRewards should have accrued
        (,, uint256 unclaimedRewards,) = distributor.nodeInfo(node);
        assertEq(unclaimedRewards, calculatedRewards);
        assertGt(unclaimedRewards, 999);
    }

    /// ---------------------------------------
    /// Test: claimRewards
    /// ---------------------------------------
    function testClaimRewards() public {
        // 1. Manager sets nonzero reward rate
        vm.prank(manager);
        distributor.setRewardRate(1 ether); // 1 token/sec for easy math

        // 2. Node joins
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // 3. Move forward in time
        vm.warp(block.timestamp + 10);

        // 4. Claim from the wrong address => revert
        vm.expectRevert("Unauthorized");
        distributor.claimRewards(node);

        // 5. Node's provider claims on behalf of that node
        (uint256 calculatedRewards,) = distributor.calculateRewards(node);
        vm.prank(nodeProvider);
        distributor.claimRewards(node);

        // Check node unclaimedRewards is zero
        (,, uint256 unclaimed,) = distributor.nodeInfo(node);
        assertEq(unclaimed, 0);

        // Check the node's token balance is correct
        uint256 nodeProviderBalance = mockRewardToken.balanceOf(nodeProvider);
        // Rewards per second = 1 token; 10 seconds => 10 tokens
        // but node has 10 computeUnits => total 1 * 10 * 10?
        // Actually, the contract logic distributes 1 token/sec / totalActiveComputeUnits
        // => 1 / 10 = 0.1 tokens/sec per compute unit
        // => in 10 secs = 10 * 0.1 = 1 token per compute unit
        // => node has 10 compute units => 10 * 1 = 10 tokens total
        // Because we are using integer division in _updateGlobalIndex,
        // and if rewardRate / totalUnits is performed as integer division,
        // you might see truncated results. (But let's assume 1 for simplicity or
        // or your contract might do more precise math if using decimals.)
        //
        // For demonstration, let's just check we got > 0
        assertEq(nodeProviderBalance, 10 ether);
        assertEq(nodeProviderBalance, calculatedRewards);
    }

    /// ---------------------------------------
    /// Test: endRewards
    /// ---------------------------------------
    function testEndRewards() public {
        // Node joins first
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        // Set a nonzero reward rate
        vm.prank(manager);
        distributor.setRewardRate(1 ether);

        // Warp 5 seconds
        vm.warp(block.timestamp + 5);

        // End rewards
        vm.prank(address(mockComputePool));
        distributor.endRewards();

        // Warp more time (should not accrue new rewards after end)
        vm.warp(block.timestamp + 100);

        // Claim
        (uint256 calculatedRewards,) = distributor.calculateRewards(node);
        vm.prank(nodeProvider);
        distributor.claimRewards(node);

        // The node's balance should reflect only the reward for the first 5 seconds
        uint256 nodeProviderBalance = mockRewardToken.balanceOf(nodeProvider);
        // 1 token/sec total / 10 computeUnits => 0.1 token/sec per unit * 10 units = 1 token/sec total
        // => 5 seconds => 5 tokens
        assertEq(nodeProviderBalance, 5 ether);
        assertEq(nodeProviderBalance, calculatedRewards);
    }

    /// ---------------------------------------
    /// TEST: Multiple Nodes
    /// ---------------------------------------
    ///
    /// Node1 joins at t=0, Node2 joins at t=15
    /// We'll set rewardRate=10 tokens/sec to illustrate
    function testMultipleNodes() public {
        // 1. Manager sets reward rate = 10 tokens/sec
        vm.prank(manager);
        distributor.setRewardRate(10 ether);

        // 2. Node1 joins at t=0 with 10 computeUnits
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);

        // Warp 15s => now t=15
        skip(15);

        // 3. Node2 joins at t=15, with 10 computeUnits as well
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 10);

        // Warp another 15s => now t=30
        skip(15);
        // 4. Let both nodes claim
        //    We'll do it from their providers
        (uint256 node1Pending,) = distributor.calculateRewards(node1);
        vm.startPrank(nodeProvider1);
        distributor.claimRewards(node1);
        vm.stopPrank();

        (uint256 node2Pending,) = distributor.calculateRewards(node2);
        vm.startPrank(nodeProvider2);
        distributor.claimRewards(node2);
        vm.stopPrank();

        // 5. Check balances
        uint256 node1ProviderBalance = mockRewardToken.balanceOf(nodeProvider1);
        uint256 node2ProviderBalance = mockRewardToken.balanceOf(nodeProvider2);

        assertEq(node1Pending, node1ProviderBalance, "Node1 pending balance mismatch");
        assertEq(node2Pending, node2ProviderBalance, "Node2 pending balance mismatch");

        // Explanation of the math (given integer division in the contract):
        //
        // For the first 15s (t=0 to t=15), only Node1 is in the pool with 10 CU.
        //   rewardRate = 10 tokens/sec => total = 10 * 15 = 150 tokens
        //   totalActiveComputeUnits = 10 => additionalIndex = 150 / 10 = 15
        //   => Node1’s unclaimed = 15 * 10 = 150 (no leftover in that step).
        //
        // Then Node2 joins at t=15, so totalActiveComputeUnits=20.
        // Next 15s (t=15 to t=30):
        //   rewardRate = 10 tokens/sec => total = 10 * 15 = 150 tokens
        //   totalActiveComputeUnits = 20 => additionalIndex = 150 / 20 = 7.5
        //   => each unit gets 7.5 more tokens
        //      => Node1 has 10 CU => +75
        //      => Node2 has 10 CU => +75
        //
        // So, final unclaimed before claiming:
        //   Node1: 150 + 75 = 225
        //   Node2: 0 + 75 = 75
        //
        // After claim, that’s the token balances:
        assertEq(node1ProviderBalance, 225 ether, "Node1 balance mismatch");
        assertEq(node2ProviderBalance, 75 ether, "Node2 balance mismatch");
    }

    /// ---------------------------------------
    /// TEST: Multiple Reward Rates
    /// ---------------------------------------
    ///
    /// 1) Node1 joins with 10 CU under rate=50 tokens/sec
    /// 2) Warp 10s
    /// 3) Manager updates reward rate to 100 tokens/sec
    /// 4) Warp 10s more
    /// 5) Node2 joins with 5 CU
    /// 6) Warp 10s more
    /// 7) Claim for both => see correct distribution
    function testMultipleRewardRates() public {
        // Step 1: set initial rate = 50 tokens/sec
        vm.prank(manager);
        distributor.setRewardRate(50 ether);

        // Node1 joins with 10 computeUnits
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);

        // Warp 10s => Node1 accumulates at 50 tokens/sec
        skip(10);

        // Step 3: Manager updates reward rate to 100 tokens/sec
        vm.prank(manager);
        distributor.setRewardRate(100 ether);

        // Warp 10s more => Node1 gets 100 tokens/sec for those 10s
        skip(10);

        // Step 5: Node2 joins with 5 computeUnits
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 5);

        // Warp 10s more => Now Node1(10 CU) & Node2(5 CU) share 100 tokens/sec
        skip(10);

        // Step 7: Claim for both from their respective providers
        (uint256 node1Pending,) = distributor.calculateRewards(node1);
        vm.startPrank(nodeProvider1);
        distributor.claimRewards(node1);
        vm.stopPrank();

        (uint256 node2Pending,) = distributor.calculateRewards(node2);
        vm.startPrank(nodeProvider2);
        distributor.claimRewards(node2);
        vm.stopPrank();

        uint256 nodeProvider1Bal = mockRewardToken.balanceOf(nodeProvider1);
        uint256 nodeProvider2Bal = mockRewardToken.balanceOf(nodeProvider2);

        assertEq(node1Pending, nodeProvider1Bal, "Node1 pending balance mismatch");
        assertEq(node2Pending, nodeProvider2Bal, "Node2 pending balance mismatch");

        // Let’s break down the rewards in each time segment:
        //
        // Segment A (t=0 -> t=10):
        //   rate = 50 tokens/sec, Node1 only with 10 CU
        //   => total = 50 * 10 = 500 tokens
        //   => totalActiveComputeUnits = 10 => additionalIndex = 500 / 10 = 50
        //   => Node1 accumulates 50 * 10 = 500
        //
        // Segment B (t=10 -> t=20):
        //   rate = 100 tokens/sec, Node1 only with 10 CU
        //   => total = 100 * 10 = 1000 tokens
        //   => totalActiveComputeUnits = 10 => additionalIndex = 1000 / 10 = 100
        //   => Node1 accumulates + (100 * 10) = 1000
        //   => So Node1 total so far = 500 + 1000 = 1500
        //
        // Segment C (t=20 -> t=30):
        //   rate = 100 tokens/sec, Node1(10 CU) + Node2(5 CU) => total = 15 CU
        //   => total = 100 * 10 = 1000 tokens
        //   => additionalIndex = 1000 / 15 = 66.666...
        //   => Node1 gets 66.666... * 10 = 666.666...
        //   => Node2 gets 66.666... * 5  = 333.333...
        //
        // Final expected:
        //   Node1: 1500 + 666.666... = 2166.666...
        //   Node2: 0 + 333.333...    = 333.333...
        //
        assertEq(nodeProvider1Bal, 2166.66666666666666666 ether, "Node1 final balance mismatch");
        assertEq(nodeProvider2Bal, 333.33333333333333333 ether, "Node2 final balance mismatch");
    }
}
