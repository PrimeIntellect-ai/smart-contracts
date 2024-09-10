// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

interface IRewards {
    /// @notice approval step to set rewards for model.
    /// @dev reward variables can only be set/updated by Prime Intellect/Owner.
    function setModelRewards(uint256 modelId) external returns (bool);

    /// @notice update reward variables for a given model.
    /// @dev can only be called by Owner.
    function updateModelRewards() external returns ();

    /// @notice users able to deposit/stake Prime tokens to a model.
    /// @dev tokens can only be deposited prior to start of training run.
    function deposit(address token, uint256 amount) external returns (uint256);

    /// @notice users able to withdraw Prime tokens from a model.
    /// @dev tokens can only be withdrawn when training run is not active.
    function withdraw() external returns ();

    /// @notice claim reward tokens from the contract.
    function claim(address token, uint256 shares) external returns (uint256);
}
