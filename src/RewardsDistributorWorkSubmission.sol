// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IRewardsDistributor.sol";
import "./interfaces/IComputePool.sol";
import "./interfaces/IComputeRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract RewardsDistributorWorkSubmission is IRewardsDistributor, AccessControlEnumerable {
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE");
    bytes32 public constant FEDERATOR_ROLE = keccak256("FEDERATOR_ROLE");
    bytes32 public constant REWARDS_MANAGER_ROLE = keccak256("REWARDS_MANAGER_ROLE");
    bytes32 public constant COMPUTE_POOL_ROLE = keccak256("COMPUTE_POOL_ROLE");

    IComputePool public computePool;
    IComputeRegistry public computeRegistry;
    uint256 public poolId;
    IERC20 public rewardToken; // Token to distribute
    uint256 rewardRatePerUnit;
    uint256 endTime;

    // Ring buffer config for a 24h window, 1h bucket size
    // (Adjust as needed: e.g. 12 buckets of 2h each, etc.)
    uint256 public constant NUM_BUCKETS = 24;
    uint256 public constant BUCKET_DURATION = 3600; // 1 hour

    // Holds ring-buffer data for each node
    struct NodeBuckets {
        uint256[NUM_BUCKETS] buckets; // Each bucket’s total submissions
        uint256 currentBucket; // Index of the active bucket
        uint256 lastBucketTimestamp; // Timestamp when we last rolled the bucket
        uint256 totalLast24H; // Sum of all buckets
        // Optional fields for “locked vs. unlocked” reward logic:
        uint256 totalAllSubmissions; // Running total of all-time submissions
        uint256 lastClaimed; // Last totalAllSubmissions used in claim
    }

    mapping(address => NodeBuckets) private nodeBuckets;

    // --------------------------------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------------------------------

    constructor(IComputePool _computePool, IComputeRegistry _computeRegistry, uint256 _poolId) {
        computePool = _computePool;
        computeRegistry = _computeRegistry;
        poolId = _poolId;

        rewardToken = IERC20(computePool.getRewardToken());
        _grantRole(COMPUTE_POOL_ROLE, address(computePool));
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // By default, grant the REWARDS_MANAGER_ROLE to your Federator
        address primeContract = computePool.getRoleMember(PRIME_ROLE, 0);
        address federator = IAccessControlEnumerable(primeContract).getRoleMember(FEDERATOR_ROLE, 0);
        _grantRole(REWARDS_MANAGER_ROLE, federator);
    }

    // --------------------------------------------------------------------------------------------
    // Per-node ring buffer rolling
    // --------------------------------------------------------------------------------------------

    function _rollBuckets(address node) internal {
        NodeBuckets storage nb = nodeBuckets[node];
        uint256 elapsed = (block.timestamp - nb.lastBucketTimestamp) / BUCKET_DURATION;
        if (elapsed > 0) {
            // If more than 24h has passed, reset everything
            if (elapsed >= NUM_BUCKETS) {
                for (uint256 i = 0; i < NUM_BUCKETS; i++) {
                    nb.buckets[i] = 0;
                }
                nb.currentBucket = 0;
                nb.totalLast24H = 0;
            } else {
                // Advance the ring buffer by 'elapsed' buckets
                for (uint256 i = 0; i < elapsed; i++) {
                    nb.currentBucket = (nb.currentBucket + 1) % NUM_BUCKETS;
                    // Subtract the old bucket from total, then zero it
                    nb.totalLast24H -= nb.buckets[nb.currentBucket];
                    nb.buckets[nb.currentBucket] = 0;
                }
            }
            // Snap lastBucketTimestamp forward by however many full buckets elapsed
            nb.lastBucketTimestamp += elapsed * BUCKET_DURATION;
        }
    }

    // --------------------------------------------------------------------------------------------
    // Submission
    // --------------------------------------------------------------------------------------------

    /// @notice Called by the pool to record that `node` performed `workUnits`.
    ///         This increments the node's current bucket, ensuring O(1) ring buffer updates.
    function submitWork(address node, uint256 workUnits) external onlyRole(COMPUTE_POOL_ROLE) {
        require(endTime == 0, "Rewards have ended");
        require(computePool.isNodeInPool(poolId, node), "Node not in pool");

        NodeBuckets storage nb = nodeBuckets[node];
        // Roll forward first to ensure we're in the correct active bucket
        _rollBuckets(node);

        // Increment the current bucket
        nb.buckets[nb.currentBucket] += workUnits;
        nb.totalLast24H += workUnits;

        // Track an all-time total if you want to do "locked/unlocked" logic
        nb.totalAllSubmissions += workUnits;

        // Optionally, ensure lastBucketTimestamp is set if first time
        if (nb.lastBucketTimestamp == 0) {
            nb.lastBucketTimestamp = block.timestamp;
        }
    }

    // --------------------------------------------------------------------------------------------
    // "Locked for 24h" Reward Logic
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Bucket approach:
     *  - totalAllSubmissions: total submissions ever done by this node.
     *  - totalLast24H: the sum of the ring buffer's most recent 24h.
     *    We treat that as "locked."
     *  - The difference (totalAllSubmissions - totalLast24H) is "unlocked."
     *  - We track lastClaimed to ensure we only pay incremental amounts.
     */
    function claimRewards(address node) external {
        require(rewardRatePerUnit != 0, "Rate not set");
        require(msg.sender == computeRegistry.getNodeProvider(node), "Unauthorized");

        _rollBuckets(node);

        NodeBuckets storage nb = nodeBuckets[node];

        uint256 unlockedNow = nb.totalAllSubmissions - nb.totalLast24H;
        uint256 claimable = unlockedNow - nb.lastClaimed;
        if (claimable == 0) {
            return; // nothing to claim
        }
        nb.lastClaimed = unlockedNow;

        uint256 tokensToSend = claimable * rewardRatePerUnit;
        require(tokensToSend <= rewardToken.balanceOf(address(this)), "Insufficient tokens");

        rewardToken.transfer(msg.sender, tokensToSend);

        emit RewardsClaimed(poolId, msg.sender, node, tokensToSend);
    }

    // --------------------------------------------------------------------------------------------
    // "Slash Pending Rewards" Logic
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Slashes the pending rewards for a node.
     *         This is useful for slashing rewards if a node is inactive or misbehaving.
     *         It resets the node's buckets and totalLast24H to zero.
     *         Optionally, you can send the slashed tokens to a treasury or burn them.
     * @param node The address of the node whose pending rewards are to be slashed.
     * @dev This function can only be called by the REWARDS_MANAGER_ROLE.
     *      It resets the node's buckets and totalLast24H to zero.
     */
    function slashPendingRewards(address node) external {
        // this can be called directly by the REWARDS_MANAGER_ROLE or by the COMPUTE_POOL_ROLE
        // through a work invalidation submission
        require(hasRole(REWARDS_MANAGER_ROLE, msg.sender) || hasRole(COMPUTE_POOL_ROLE, msg.sender), "Unauthorized");

        _rollBuckets(node);
        NodeBuckets storage nb = nodeBuckets[node];
        uint256 pending24h = nb.totalLast24H;
        if (pending24h == 0) {
            return; // nothing to slash
        }
        for (uint256 i = 0; i < NUM_BUCKETS; i++) {
            nb.buckets[i] = 0; // reset to zero
        }
        nb.totalAllSubmissions -= pending24h; // decrement total
        nb.totalLast24H = 0; // reset to zero
        nb.currentBucket = 0; // reset to first bucket
        nb.lastBucketTimestamp = 0; // reset to zero

        // Optionally, send the slashed tokens to a treasury or burn them
        // rewardToken.transfer(treasury, pending24h * rewardRatePerUnit);

        address provider = computeRegistry.getNodeProvider(node); // get the provider for the node
        emit PendingRewardsSlashed(poolId, provider, node, pending24h * rewardRatePerUnit);
    }

    // --------------------------------------------------------------------------------------------
    // Optional informational views
    // --------------------------------------------------------------------------------------------

    function calculateRewards(address node) external view returns (uint256, uint256) {
        require(rewardRatePerUnit != 0, "Rate not set");

        NodeBuckets memory nb = nodeBuckets[node];

        // Simulate the ring buffer if updated "now"
        uint256 elapsed = (block.timestamp - nb.lastBucketTimestamp) / BUCKET_DURATION;
        uint256 simulatedTotalLast24H = nb.totalLast24H;
        if (elapsed >= NUM_BUCKETS) {
            simulatedTotalLast24H = 0; // older than 24h
        } else if (elapsed > 0) {
            // Subtract out each elapsed bucket
            // (This is only an approximate view—no state changes here.)
            // Safe to loop up to `elapsed` because `elapsed` < NUM_BUCKETS.
            uint256 idx = nb.currentBucket;
            for (uint256 i = 0; i < elapsed; i++) {
                idx = (idx + 1) % NUM_BUCKETS;
                simulatedTotalLast24H -= nb.buckets[idx];
            }
        }
        // "Unlocked so far" if we hypothetically updated now
        uint256 unlockedNow = nb.totalAllSubmissions - simulatedTotalLast24H;
        uint256 claimable = unlockedNow - nb.lastClaimed;
        uint256 claimableTokens = claimable * rewardRatePerUnit;
        uint256 lockedTokens = simulatedTotalLast24H * rewardRatePerUnit;
        return (claimableTokens, lockedTokens);
    }

    function nodeInfo(address node)
        external
        view
        returns (uint256 last24H, uint256 totalAll, uint256 lastClaimed_, bool isActive)
    {
        NodeBuckets storage nb = nodeBuckets[node];
        last24H = nb.totalLast24H;
        totalAll = nb.totalAllSubmissions;
        lastClaimed_ = nb.lastClaimed;
        isActive = computePool.isNodeInPool(poolId, node);
    }

    // --------------------------------------------------------------------------------------------
    // The following methods are left for compatibility with the compute based rewards distributor
    // --------------------------------------------------------------------------------------------

    function setRewardRate(uint256 newRate) external onlyRole(REWARDS_MANAGER_ROLE) {
        require(rewardRatePerUnit == 0, "Rate can only be set once");
        rewardRatePerUnit = newRate;
    }

    function getRewardRate() external view returns (uint256) {
        return rewardRatePerUnit;
    }

    function joinPool(address node) external onlyRole(COMPUTE_POOL_ROLE) {
        // If special logic is required on node join, add it here.
        if (nodeBuckets[node].lastBucketTimestamp == 0) {
            nodeBuckets[node].lastBucketTimestamp = block.timestamp;
        }
    }

    function leavePool(address node) external onlyRole(COMPUTE_POOL_ROLE) {
        // Optionally roll + finalize the node's data. Zero out buckets, etc.
        _rollBuckets(node);
    }

    function endRewards() external onlyRole(COMPUTE_POOL_ROLE) {
        // We freeze further submissions here.
        require(endTime == 0, "Already ended");
        endTime = block.timestamp;
    }

    // --------------------------------------------------------------------------------------------
    // Soft slash functions for batch work scenarios
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Removes specific work units from a node's submissions (soft slash).
     *         This is useful when work is incomplete and you want to remove
     *         work submissions without harsh penalties.
     * @param node The address of the node whose work should be removed.
     * @param workUnits The number of work units to remove.
     * @dev This function can only be called by the COMPUTE_POOL_ROLE.
     *      It removes work from the current bucket and adjusts totals accordingly.
     */
    function removeWork(address node, uint256 workUnits) external onlyRole(COMPUTE_POOL_ROLE) {
        if (workUnits == 0) return; // No-op if no work to remove

        NodeBuckets storage nb = nodeBuckets[node];
        _rollBuckets(node);

        // Ensure we don't remove more than what exists
        uint256 toRemove = workUnits > nb.totalLast24H ? nb.totalLast24H : workUnits;
        if (toRemove == 0) return; // Nothing to remove

        // Remove from current bucket first, then work backwards if needed
        uint256 remaining = toRemove;
        uint256 bucketIdx = nb.currentBucket;

        // Remove from buckets, starting with the oldest one
        for (uint256 i = 0; i < NUM_BUCKETS && remaining > 0; i++) {
            bucketIdx = (bucketIdx + 1) % NUM_BUCKETS; // Move forward in the ring buffer
            uint256 bucketAmount = nb.buckets[bucketIdx];
            if (bucketAmount > 0) {
                uint256 removeFromBucket = remaining > bucketAmount ? bucketAmount : remaining;
                nb.buckets[bucketIdx] -= removeFromBucket;
                remaining -= removeFromBucket;
            }
        }

        // Update totals
        uint256 actualRemoved = toRemove - remaining;
        nb.totalLast24H -= actualRemoved;

        // Also reduce total submissions to maintain consistency
        nb.totalAllSubmissions = nb.totalAllSubmissions > actualRemoved ? nb.totalAllSubmissions - actualRemoved : 0;
    }
}
