// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

event RewardRate(uint256 indexed poolId, uint256 rate);

event RewardsClaimed(uint256 indexed poolId, address indexed provider, address indexed nodekey, uint256 reward);

event PendingRewardsSlashed(
    uint256 indexed poolId, address indexed provider, address indexed node, uint256 slashedAmount
);

interface IRewardsDistributor {
    function calculateRewards(address node) external view returns (uint256, uint256);
    function claimRewards(address node) external;
    function setRewardRate(uint256 newRate) external;
    function getRewardRate() external view returns (uint256);
    function slashPendingRewards(address node) external;
    function endRewards() external;
    function joinPool(address node) external;
    function leavePool(address node) external;
    function submitWork(address node, uint256 workUnits) external;

    // Soft slash function for work removal
    function removeWork(address node, uint256 workUnits) external;
}
