// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ITrainingManager {
    enum ModelStatus {
        Registered,
        Running,
        Paused,
        Done
    }

    function registerModel(
        string memory name
    ) external returns (uint256);

    function name(uint256 trainingRunId) external view returns (string memory);

    /// @notice Gets status of training run for id
    function getModelStatus(
        uint256 trainingRunId
    ) external view returns (ModelStatus);

    function joinTrainingRun(
        address account,
        uint256 trainingRunId
    ) external returns (bool);

    /// @notice Registers compute node for training run
    /// @dev Function not called by compute node, so registration needs knowledge of compute nodes
    function whitelistComputeNode(address account) external;

    /// @notice Returns if compute node is whitelisted or not
    function isComputeNodeWhitelisted(address account) external returns (bool);

    function startTrainingRun(uint256 trainingRunId) external returns (bool);

    /// @notice Ends training run
    function endTrainingRun(uint256 trainingRunId) external returns (bool);

    /// @notice Submits attestion that compute was utilized for training by node
    /// @dev Function called by compute node, unlike the other functions on this interface
    function submitAttestation(
        address account,
        uint256 trainingRunId,
        bytes memory attestation
    ) external returns (bool);

    function getAttestationsCount(
        uint256 trainingRunId,
        address account
    ) external returns (uint256);

    function getComputeNodesForTrainingRun(
        uint256 trainingRunId
    ) external returns (address[] memory);

    function getAttestationsForComputeNode(
        uint256 trainingId,
        address account
    ) external returns (bytes[] memory);

    function getTrainingRunInfo(
        uint256 trainingRunId
    )
        external
        view
        returns (
            string memory _name,
            ModelStatus status,
            address[] memory computeNodes
        );

    function getTrainingRunEndTime(
        uint256 trainingRunId
    ) external returns (uint256);

    function pauseTrainingRun(uint256 trainingRunId) external returns (bool);
    function resumeTrainingRun(uint256 trainingRunId) external returns (bool);
}
