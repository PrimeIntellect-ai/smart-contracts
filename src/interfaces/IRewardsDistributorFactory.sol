// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./IComputePool.sol";
import "./IComputeRegistry.sol";
import "./IRewardsDistributor.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

event NewRewardsDistributor(address indexed rewardsDistributor, address indexed computePool, uint256 indexed poolId);

interface IRewardsDistributorFactory is IAccessControl {
    function setComputePool(IComputePool _computePool) external;
    function createRewardsDistributor(IComputeRegistry _computeRegistry, uint256 _poolId)
        external
        returns (IRewardsDistributor);
}
