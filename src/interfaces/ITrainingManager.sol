// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ITrainingManager {
    enum ModelStatus {
        Registered,
        Running,
        Done
    }

    function registerModel(
        string memory name,
        uint256 budget
    ) external returns (uint256);

    function getModelStatus(
        uint256 trainingRunId
    ) external view returns (ModelStatus);

    function name(uint256 trainingRunId) external view returns (string memory);

    function budget(uint256 trainingRunId) external view returns (uint256);

    function isComputeNodeValid(address account) external view returns (bool);

    function registerForTrainingRun(
        address account,
        string memory ipAddress,
        uint256 trainingRunId
    ) external returns (bool);

    /// @notice Submits attestion that compute was utilized for training by node
    /// @dev Function called by compute node, unlike the other functions on this interface
    function submitAttestation(
        address account,
        uint256 trainingRunId,
        bytes memory attestation
    ) external returns (bool);

    function getComputeNodesForTrainingRun(
        uint256 trainingRunId
    ) external view returns (address[] memory);

    function getAttestationsForComputeNode(
        address account
    ) external view returns (bytes[] memory);

    function getAttestations(
        uint256 trainingRunId,
        address computeNode
    ) external view returns (bool);

    function startTrainingRun(uint256 trainingRunId) external returns (bool);

    /// @notice Ends training run
    function endTrainingRun(uint256 trainingRunId) external returns (bool);

    function getTrainingRunEndTime(
        uint256 trainingRunId
    ) external view returns (uint256);
}
