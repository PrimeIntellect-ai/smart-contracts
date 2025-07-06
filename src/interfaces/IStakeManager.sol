// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

event Stake(address staker, uint256 amount);

event Unstake(address staker, uint256 amount, uint256 index);

event Withdraw(address staker, uint256 amount);

event Slashed(address staker, uint256 amount, bytes reason);

event Rebond(address staker, uint256 amount);

event UpdateUnbondingPeriod(uint256 period);

event StakeMinimumUpdate(uint256 minimum);

event PendingBondRemoved(address staker, uint256 amount, uint256 index);

event PendingBondUpdated(address staker, uint256 amount, uint256 index, uint256 timestamp);

interface IStakeManager is IAccessControlEnumerable {
    struct Unbond {
        uint256 amount;
        uint256 timestamp;
    }

    function stake(address staker, uint256 amount) external;
    function unstake(address staker, uint256 amount) external;
    function rebond(address staker, uint256 amount) external;
    function withdraw() external;
    function slash(address staker, uint256 amount, bytes calldata reason) external returns (uint256 slashed);

    function setUnbondingPeriod(uint256 period) external;
    function setStakeMinimum(uint256 minimum) external;

    function getStake(address staker) external view returns (uint256);
    function getTotalStaked() external view returns (uint256);
    function getPendingUnbonds(address staker) external view returns (Unbond[] memory);
    function getUnbondAtIndex(address staker, uint256 index) external view returns (Unbond memory);
    function getPendingUnbondTotal(address staker) external view returns (uint256);
    function getUnbondingPeriod() external view returns (uint256);
    function getTotalUnbonding() external view returns (uint256);
    function getStakeMinimum() external view returns (uint256);
}
