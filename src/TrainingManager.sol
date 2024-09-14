// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {ITrainingManager} from "./interfaces/ITrainingManager.sol";

contract TrainingManager is ITrainingManager {
    mapping(uint256 trainingRunId => TrainingRunStatus status)
        private trainingRunStatuses;
    mapping(address computeNodeAccount => string ipAddress)
        private registeredComputeNodes;
    mapping(uint256 trainingRunId => address[] computeNodes)
        private trainingRunComputeNodes;
    mapping(address computeNodeAccount => bytes[] attestations)
        private computeAttestations;

    string private _name;
    uint256 private _budget;
    uint256 public trainingRunIdCount;

    event EndTrainingRun(uint256 trainingRunId);

    /**
     * @dev Sets the values for {name} and {budget}.
     *
     */
    constructor(string memory name_, uint256 memory budget_) {
        _name = name_;
        _budget = budget_;
    }

    /**
     * @dev Returns the name of the training run.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the budget for the training run
     */
    function budget() public view virtual returns (uint256 memory) {
        return _budget;
    }

    function registerTrainingRun() external returns (string) {
        trainingRunIdCount++;
        trainingRunStatuses[trainingRunIdCount] = TrainingRunStatus.Registered;
        return trainingRunIdCount;
    }

    function getTrainingRunStatus(
        uint256 trainingRunId
    ) external returns (TrainingRunStatus) {
        return trainingRunStatuses[trainingRunId];
    }

    function registerComputeNode(
        address account,
        string ipAddress,
        uint256 trainingRunId
    ) external returns (bool) {
        registeredComputeNodes[account] = ipAddress;
        trainingRunComputeNodes[trainingRunId].push(account);
        return true;
    }

    function isComputeNodeValid(address account) external returns (bool) {
        if (registeredComputeNodes[account].isValue) return true;
        return false;
    }

    function startTrainingRun(uint256 trainingRunId) external returns (bool) {
        trainingRunStatuses[trainingRunId] = TrainingRunStatus.Running;
    }

    function submitAttestation(
        address account,
        uint256 trainingRunId,
        bytes attestation
    ) external returns (bool) {
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
        computeAttestations[computeNodeAccount].push(attestation);
        return true;
    }

    function getComputeNodesForTrainingRun(
        uint256 trainingRunId
    ) returns (address[]) {
        return trainingRunComputeNodes[trainingRunId];
    }

    function getAttestationsForComputeNode(address account) returns (bytes[]) {
        return computeAttestations[account];
    }

    function endTrainingRun(uint256 trainingRunId) external returns (bool) {
        trainingRunStatuses[trainingRunId] = TrainingRunStatus.Done;
        emit EndTrainingRun(trainingRunId);
    }
}
