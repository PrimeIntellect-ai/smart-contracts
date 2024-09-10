// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

/// @dev Interface for training specific logic
/// @dev Required metadata includes name and budget
interface ITrainingManager {

    /// @notice Defines status of training run
    enum TrainingRunStatus {
        Registered,
        Running,
        Done
    }

    /// @notice Creating training returns unique string
    function registerTrainingRun() external returns (string);

    /// @notice Gets status of training run for id
    function getTrainingRunStatus(string trainingRunId) external returns (TrainingRunStatus);

    /// @notice Registers compute node for training run
    /// @dev Function not called by compute node, so registration needs knowledge of compute nodes
    function registerComputeNode(address account, string ipAddress, string trainingRunId) external returns (bool);

    /// @notice Returns if compute node is valid by ip
    function isComputeNodeValid(string ipAddress) external returns (bool);

    /// @notice Starts training run
    function startTrainingRun(string trainingRunId) external returns (bool);

    /// @notice Submits attestion that compute was utilized for training by node
    /// @dev Function called by compute node, unlike the other functions on this interface
    function submitAttestation(address account, string trainingRunId, bytes attestation) external returns (bool);

    /// @notice Ends training run
    function endTrainingRun(string trainingRunId) external returns (bool);

    /// @notice Returns the name of the training run
    function name() external view returns (string memory);

    /// @notice Returns the budget of the training run
    function budget() external view returns (uint256 memory);

}
