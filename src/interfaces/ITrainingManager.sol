// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ITrainingManager {
    enum ModelStatus {
        Registered,
        Running,
        Done
    }

    function registerModel(string memory name, uint256 budget) external returns (uint256);

    function name(uint256 trainingRunId) external view returns (string memory);

    function budget(uint256 trainingRunId) external view returns (uint256);

    /// @notice Gets status of training run for id
    function getTrainingRunStatus(uint256 trainingRunId) external returns (ModelStatus);

    function joinTrainingRun(address account, string memory ipAddress, uint256 trainingRunId) external returns (bool);

    /// @notice Registers compute node for training run
    /// @dev Function not called by compute node, so registration needs knowledge of compute nodes
    function addComputeNode(address account) external;

    /// @notice Returns if compute node is valid by ip
    function isComputeNodeValid(address account) external returns (bool);

    function startTrainingRun(uint256 trainingRunId) external returns (bool);

    /// @notice Ends training run
    function endTrainingRun(uint256 trainingRunId) external returns (bool);

    /// @notice Submits attestion that compute was utilized for training by node
    /// @dev Function called by compute node, unlike the other functions on this interface
    function submitAttestation(address account, uint256 trainingRunId, bytes memory attestation)
        external
        returns (bool);

    function getAttestations(uint256 trainingRunId, address account) external returns (uint256);

    function getComputeNodesForTrainingRun(uint256 trainingRunId) external returns (address[] memory);

    function getAttestationsForComputeNode(uint256 trainingId, address account) external returns (bytes[] memory);

    function getTrainingRunEndTime(uint256 trainingRunId) external returns (uint256);
}
