// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./IComputeRegistry.sol";
import "./IRewardsDistributor.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

event ComputePoolCreated(uint256 indexed poolId, uint256 indexed domainId, address indexed creator);

event ComputePoolStarted(uint256 indexed poolId, uint256 timestamp);

event ComputePoolEnded(uint256 indexed poolId);

event ComputePoolURIUpdated(uint256 indexed poolId, string uri);

event ComputePoolLimitUpdated(uint256 indexed poolId, uint256 limit);

event ComputePoolJoined(uint256 indexed poolId, address indexed provider, address[] nodekeys);

event ComputePoolLeft(uint256 indexed poolId, address indexed provider, address nodekey);

event ComputePoolNodeEjected(uint256 indexed poolId, address indexed provider, address nodekey);

event ComputePoolPurgedProvider(uint256 indexed poolId, address indexed provider);

event ComputePoolProviderBlacklisted(uint256 indexed poolId, address indexed provider);

event ComputePoolNodeBlacklisted(uint256 indexed poolId, address indexed provider, address nodekey);

interface IComputePool is IAccessControlEnumerable {
    enum PoolStatus {
        PENDING,
        ACTIVE,
        COMPLETED
    }

    struct PoolInfo {
        uint256 poolId;
        uint256 domainId;
        string poolName;
        address creator;
        address computeManagerKey;
        uint256 creationTime;
        uint256 startTime;
        uint256 endTime;
        string poolDataURI;
        address poolValidationLogic;
        uint256 totalCompute;
        uint256 computeLimit;
        PoolStatus status;
    }

    // Note: computeLimit == 0 implies no limit
    function createComputePool(
        uint256 domainId,
        address computeManagerKey,
        string calldata poolName,
        string calldata poolDataURI,
        uint256 computeLimit
    ) external returns (uint256);
    function startComputePool(uint256 poolId) external;
    function endComputePool(uint256 poolId) external;
    function joinComputePool(
        uint256 poolId,
        address provider,
        address nodekeys,
        uint256 nonce,
        uint256 expiration,
        bytes memory signature
    ) external;
    function joinComputePool(
        uint256 poolId,
        address provider,
        address[] memory nodekeys,
        uint256[] memory nonces,
        uint256[] memory expirations,
        bytes[] memory signatures
    ) external;
    function leaveComputePool(uint256 poolId, address provider, address nodekey) external;
    function leaveComputePool(uint256 poolId, address provider, address[] memory nodekeys) external;
    function changeComputePool(
        uint256 fromPoolId,
        uint256 toPoolId,
        address[] memory nodekeys,
        uint256[] memory nonces,
        uint256[] memory expirations,
        bytes[] memory signatures
    ) external;
    function updateComputePoolURI(uint256 poolId, string calldata poolDataURI) external;
    function updateComputeLimit(uint256 poolId, uint256 computeLimit) external;
    function purgeProvider(uint256 poolId, address provider) external;
    function ejectNode(uint256 poolId, address nodekey) external;
    function submitWork(uint256 poolId, address nodekey, bytes calldata data) external;
    function invalidateWork(uint256 poolId, bytes calldata data) external returns (address, address);
    function softInvalidateWork(uint256 poolId, bytes calldata data) external returns (address, address, uint256);
    function blacklistProvider(uint256 poolId, address provider) external;
    function blacklistProviderList(uint256 poolId, address[] memory providers) external;
    function blacklistAndPurgeProvider(uint256 poolId, address provider) external;
    function blacklistNode(uint256 poolId, address nodekey) external;
    function blacklistNodeList(uint256 poolId, address[] memory nodekeys) external;
    function getComputePool(uint256 poolId) external view returns (PoolInfo memory);
    function getComputePoolProviders(uint256 poolId) external view returns (address[] memory);
    function getComputePoolNodes(uint256 poolId) external view returns (address[] memory);
    function getComputePoolTotalCompute(uint256 poolId) external view returns (uint256);
    function getProviderActiveNodesInPool(uint256 poolId, address provider) external view returns (uint256);
    function getRewardToken() external view returns (address);
    function getRewardDistributorForPool(uint256 poolId) external view returns (IRewardsDistributor);
    function isNodeInPool(uint256 poolId, address nodekey) external view returns (bool);
    function isProviderInPool(uint256 poolId, address provider) external view returns (bool);
    function isProviderBlacklistedFromPool(uint256 poolId, address provider) external returns (bool);
    function isNodeBlacklistedFromPool(uint256 poolId, address nodekey) external returns (bool);
}
