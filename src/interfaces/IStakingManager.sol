// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IStakingManager {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Slashed(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);
    event AttestationRecorded(address indexed account, uint256 trainingRunId);

    /// @notice Stake a specified amount of ASI tokens
    /// @param _amount The amount of ASI tokens to stake
    function stake(uint256 _amount) external;

    /// @notice Withdraw a specified amount of staked ASI tokens
    /// @param _amount The amount of ASI tokens to withdraw
    function withdraw(uint256 _amount) external;

    /// @notice Slash a specific account, reducing its staked ASI tokens
    /// @param _account The address of the account to slash
    /// @param _amount The amount of tokens to slash
    function slash(address _account, uint256 _amount) external;

    /// @notice View the pending rewards for a specific account
    /// @param account The address of the compute node
    /// @return The amount of pending rewards
    function pendingRewards(address account) external view returns (uint256);

    /// @notice Claim rewards for the caller after the delay period has passed
    function claim() external;

    /// @notice Record an attestation for a compute node in a specific training run
    /// @param account The address of the compute node
    /// @param trainingRunId The ID of the training run
    function recordAttestation(address account, uint256 trainingRunId) external;

    /// @notice Get the balance of ASI tokens held by the staking contract
    /// @return The balance of ASI tokens held by this contract
    function getContractBalance() external view returns (uint256);

    /// @notice Get the staked balance of a compute node
    /// @param account The address of the compute node
    /// @return The current staked balance of the compute node
    function getComputeNodeBalance(
        address account
    ) external view returns (uint256);
}
