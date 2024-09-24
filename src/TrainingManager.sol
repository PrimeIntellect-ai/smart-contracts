// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "./interfaces/ITrainingManager.sol";
import "./StakingManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TrainingManager is ITrainingManager, AccessControl {
    StakingManager public stakingManager;

    struct ComputeNodeInfo {
        bool isRegistered;
        bytes[] attestations;
        uint256 index; // index in the computeNodesArray
    }

    struct TrainingRunInfo {
        mapping(address => ComputeNodeInfo) computeNodes;
        address[] computeNodesArray;
    }

    mapping(uint256 => TrainingRunInfo) internal trainingRunData;

    mapping(uint256 => ModelStatus) private trainingRunStatuses;
    mapping(uint256 => string) private trainingRunNames;
    mapping(uint256 => uint256) private trainingRunBudgets;
    mapping(address => string) private registeredComputeNodes;
    mapping(address => bool) private registeredValidComputeNodes;
    mapping(uint256 => address[]) private trainingRunComputeNodes;
    mapping(address => bytes[]) private computeAttestations;

    mapping(bytes32 => TrainingRunInfo) internal trainingRuns;
    mapping(address => bytes32[]) public computeNodeTrainingHashes;

    uint256 public trainingRunIdCount;

    event EndTrainingRun(uint256 trainingRunId);
    event AttestationSubmitted(
        address indexed computeNode,
        uint256 trainingRunId
    );

    constructor(StakingManager _stakingManager) {
        stakingManager = _stakingManager;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //////////////////////////////////////
    ////           MODEL OWNERS        ///
    //////////////////////////////////////

    function registerModel(
        string memory _name,
        uint256 _budget
    ) external override returns (uint256) {
        trainingRunIdCount++;
        trainingRunStatuses[trainingRunIdCount] = ModelStatus.Registered;
        trainingRunNames[trainingRunIdCount] = _name;
        trainingRunBudgets[trainingRunIdCount] = _budget;
        return trainingRunIdCount;
    }

    /// @notice returns status of training run
    function getModelStatus(
        uint256 trainingRunId
    ) external view override returns (ModelStatus) {
        return trainingRunStatuses[trainingRunId];
    }

    /// @notice returns the name of the training run
    function name(
        uint256 trainingRunId
    ) public view override returns (string memory) {
        return trainingRunNames[trainingRunId];
    }

    /// @notice Returns the budget for the training run
    function budget(
        uint256 trainingRunId
    ) public view override returns (uint256) {
        return trainingRunBudgets[trainingRunId];
    }

    //////////////////////////////////////
    ////      COMPUTE PROVIDERS        ///
    //////////////////////////////////////

    function isComputeNodeValid(
        address account
    ) public view override returns (bool) {
        return registeredValidComputeNodes[account];
    }

    function registerForTrainingRun(
        address account,
        string memory ipAddress,
        uint256 trainingRunId
    ) external override returns (bool) {
        require(
            stakingManager.getComputeNodeBalance(account) >=
                stakingManager.MIN_DEPOSIT(),
            "Insufficient staked balance"
        );
        require(bytes(ipAddress).length > 0, "IP address cannot be empty");

        registeredComputeNodes[account] = ipAddress;
        registeredValidComputeNodes[account] = true;
        trainingRunComputeNodes[trainingRunId].push(account);
        return true;
    }

    function submitAttestation(
        address account,
        uint256 trainingRunId,
        bytes memory attestation
    ) external override returns (bool) {
        bool doesTrainingRunContainNodeAddress = false;
        for (
            uint i = 0;
            i < trainingRunComputeNodes[trainingRunId].length;
            i++
        ) {
            if (account == trainingRunComputeNodes[trainingRunId][i]) {
                doesTrainingRunContainNodeAddress = true;
                break;
            }
        }
        if (!doesTrainingRunContainNodeAddress) return false;
        computeAttestations[account].push(attestation);
        emit AttestationSubmitted(account, trainingRunId);
        return true;
    }

    function getComputeNodesForTrainingRun(
        uint256 trainingRunId
    ) external view override returns (address[] memory) {
        return trainingRunComputeNodes[trainingRunId];
    }

    function getAttestationsForComputeNode(
        address account
    ) external view override returns (bytes[] memory) {
        return computeAttestations[account];
    }

    function getAttestations(
        uint256 trainingRunId,
        address computeNode
    ) public view override returns (bool) {
        return
            trainingRunData[trainingRunId]
                .computeNodes[computeNode]
                .isRegistered;
    }

    function startTrainingRun(
        uint256 trainingRunId
    ) external override returns (bool) {
        trainingRunStatuses[trainingRunId] = ModelStatus.Running;
        return true;
    }

    function endTrainingRun(
        uint256 trainingRunId
    ) external override returns (bool) {
        trainingRunStatuses[trainingRunId] = ModelStatus.Done;
        emit EndTrainingRun(trainingRunId);
        return true;
    }

    function getTrainingRunEndTime(
        uint256 trainingRunId
    ) external view override returns (uint256) {
        // This function should return the end time of the training run
        // For now, it's returning the current block timestamp as a placeholder
        return block.timestamp;
    }
}
