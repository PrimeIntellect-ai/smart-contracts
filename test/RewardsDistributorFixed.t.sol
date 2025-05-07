// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RewardsDistributorFixed.sol";
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

    function setDistributorContract(RewardsDistributorFixed _distributor) external {
        distributor = _distributor;
    }

    function getComputePoolTotalCompute(uint256 _poolId) external view returns (uint256) {
        _poolId == _poolId;
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

contract RewardsDistributorFixedTest is Test {
    RewardsDistributorFixed public distributor;
    MockComputePool public mockComputePool;
    MockComputeRegistry public mockComputeRegistry;
    MockERC20 public mockRewardToken;

    // Test addresses
    address public manager = address(0x1); // Has REWARDS_MANAGER_ROLE
    address public computePoolAddress = address(0x2);
    address public nodeProvider = address(0x3);
    address public node = address(0x4);

    // Additional nodes/providers
    address public node1 = address(0x5);
    address public node2 = address(0x6);
    address public nodeProvider1 = address(0x7);
    address public nodeProvider2 = address(0x8);

    function setUp() public {
        mockRewardToken = new MockERC20("MockToken", "MTK");
        mockRewardToken.mint(address(this), 1_000_000 ether);

        mockComputeRegistry = new MockComputeRegistry();
        mockComputePool = new MockComputePool(address(mockRewardToken), 1, mockComputeRegistry);

        distributor = new RewardsDistributorFixed(
            IComputePool(address(mockComputePool)), IComputeRegistry(address(mockComputeRegistry)), 1
        );

        distributor.grantRole(distributor.REWARDS_MANAGER_ROLE(), manager);
        mockRewardToken.transfer(address(distributor), 500_000 ether);
        mockComputeRegistry.setNodeProvider(node, nodeProvider);
        mockComputeRegistry.setNodeProvider(node1, nodeProvider1);
        mockComputeRegistry.setNodeProvider(node2, nodeProvider2);
        mockComputePool.setDistributorContract(distributor);
    }

    /// ---------------------------------------
    /// Test: setRewardRate
    /// ---------------------------------------
    function testSetRewardRate() public {
        assertEq(distributor.rewardRatePerSecond(), 0);

        vm.prank(node);
        vm.expectRevert();
        distributor.setRewardRate(10);

        vm.prank(manager);
        distributor.setRewardRate(10);
        assertEq(distributor.rewardRatePerSecond(), 10);
    }

    /// ---------------------------------------
    /// Test: joinPool
    /// ---------------------------------------
    function testJoinPool() public {
        (uint256 cu,,, bool isActive) = distributor.nodeInfo(node);
        assertEq(cu, 0);
        assertFalse(isActive);

        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        (cu,,, isActive) = distributor.nodeInfo(node);
        assertEq(cu, 10);
        assertTrue(isActive);

        vm.expectRevert("Node already active");
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);
    }

    /// ---------------------------------------
    /// Test: leavePool
    /// ---------------------------------------
    function testLeavePool() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        (,,, bool isActive) = distributor.nodeInfo(node);
        assertTrue(isActive);

        vm.prank(manager);
        distributor.setRewardRate(1 ether);

        vm.warp(block.timestamp + 100);

        vm.prank(address(mockComputePool));
        mockComputePool.leaveComputePool(node);

        (,,, isActive) = distributor.nodeInfo(node);
        assertFalse(isActive);

        (uint256 calculatedRewards,) = distributor.calculateRewards(node);
        (,, uint256 unclaimedRewards,) = distributor.nodeInfo(node);
        // New logic: 1 token/sec * 10 CU * 100 sec = 1000 tokens expected.
        assertEq(unclaimedRewards, calculatedRewards);
        assertEq(unclaimedRewards, 1000 ether);
    }

    /// ---------------------------------------
    /// Test: claimRewards
    /// ---------------------------------------
    function testClaimRewards() public {
        vm.prank(manager);
        distributor.setRewardRate(1 ether); // 1 token/sec

        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        vm.warp(block.timestamp + 10);

        vm.expectRevert("Unauthorized");
        distributor.claimRewards(node);

        (uint256 calculatedRewards,) = distributor.calculateRewards(node);
        vm.prank(nodeProvider);
        distributor.claimRewards(node);

        (,, uint256 unclaimed,) = distributor.nodeInfo(node);
        assertEq(unclaimed, 0);

        uint256 providerBalance = mockRewardToken.balanceOf(nodeProvider);
        // New logic: 1 token/sec * 10 CU * 10 sec = 100 tokens.
        assertEq(providerBalance, 100 ether);
        assertEq(providerBalance, calculatedRewards);
    }

    /// ---------------------------------------
    /// Test: endRewards
    /// ---------------------------------------
    function testEndRewards() public {
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node, 10);

        vm.prank(manager);
        distributor.setRewardRate(1 ether);

        vm.warp(block.timestamp + 5);

        vm.prank(address(mockComputePool));
        distributor.endRewards();

        vm.warp(block.timestamp + 100);

        (uint256 calculatedRewards,) = distributor.calculateRewards(node);
        vm.prank(nodeProvider);
        distributor.claimRewards(node);

        uint256 providerBalance = mockRewardToken.balanceOf(nodeProvider);
        // New logic: 1 token/sec * 10 CU * 5 sec = 50 tokens.
        assertEq(providerBalance, 50 ether);
        assertEq(providerBalance, calculatedRewards);
    }

    /// ---------------------------------------
    /// TEST: Multiple Nodes
    /// ---------------------------------------
    function testMultipleNodes() public {
        vm.prank(manager);
        distributor.setRewardRate(10 ether);

        // For Node1:
        // t=0 to t=15: 10 tokens/sec * 10 CU * 15 sec = 1500 tokens.
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);

        skip(15);

        // For Node2 joining at t=15:
        // t=15 to t=30: 10 tokens/sec * 10 CU * 15 sec = 1500 tokens for each node.
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 10);

        skip(15);

        (uint256 node1Pending,) = distributor.calculateRewards(node1);
        vm.startPrank(nodeProvider1);
        distributor.claimRewards(node1);
        vm.stopPrank();

        (uint256 node2Pending,) = distributor.calculateRewards(node2);
        vm.startPrank(nodeProvider2);
        distributor.claimRewards(node2);
        vm.stopPrank();

        uint256 nodeProvider1Balance = mockRewardToken.balanceOf(nodeProvider1);
        uint256 nodeProvider2Balance = mockRewardToken.balanceOf(nodeProvider2);

        assertEq(node1Pending, nodeProvider1Balance, "Node1 pending balance mismatch");
        assertEq(node2Pending, nodeProvider2Balance, "Node2 pending balance mismatch");

        // Expected:
        // Node1: 1500 (from first segment) + 1500 (from second) = 3000 tokens.
        // Node2: 1500 tokens.
        assertEq(nodeProvider1Balance, 3000 ether, "Node1 balance mismatch");
        assertEq(nodeProvider2Balance, 1500 ether, "Node2 balance mismatch");
    }

    /// ---------------------------------------
    /// TEST: Multiple Reward Rates
    /// ---------------------------------------
    function testMultipleRewardRates() public {
        // Segment A (t=0->10): Node1 only, rate=50, 10 CU.
        // => 50 * 10 * 10 = 5000 tokens.
        vm.prank(manager);
        distributor.setRewardRate(50 ether);

        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node1, 10);

        skip(10);

        // Segment B (t=10->20): Node1 only, rate=100.
        // => 100 * 10 * 10 = 10000 tokens.
        vm.prank(manager);
        distributor.setRewardRate(100 ether);

        skip(10);

        // Segment C (t=20->30): Now Node1 (10 CU) and Node2 (5 CU).
        // For Node1: 100 * 10 * 10 = 10000 tokens.
        // For Node2: 100 * 10 * 5 = 5000 tokens.
        vm.prank(address(mockComputePool));
        mockComputePool.joinComputePool(node2, 5);

        skip(10);

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

        // Final expected totals:
        // Node1: 5000 + 10000 + 10000 = 25000 tokens.
        // Node2: 5000 tokens.
        assertEq(nodeProvider1Bal, 25000 ether, "Node1 final balance mismatch");
        assertEq(nodeProvider2Bal, 5000 ether, "Node2 final balance mismatch");
    }
}
