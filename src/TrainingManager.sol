// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {ITrainingManager} from "./interfaces/ITrainingManager.sol";

contract TrainingManager is ITrainingManager {

    mapping(uint256 trainingRunId => ModelStatus status) private trainingRunStatuses;
    mapping(uint256 trainingRunId => string name) private trainingRunNames;
    mapping(uint256 trainingRunId => uint256 budget) private trainingRunBudgets;
    mapping(address computeNodeAccount => string ipAddress) private registeredComputeNodes;
    mapping(address computeNodeAccount => bool validNode) private registeredValidComputeNodes;
    mapping(uint256 trainingRunId => address[] computeNodes) private trainingRunComputeNodes;
    mapping(address computeNodeAccount => bytes[] attestations) private computeAttestations;

    uint256 public trainingRunIdCount;

    event EndTrainingRun(uint256 trainingRunId);

    /**
     * @dev Initializes a new training run
     */
    function registerTrainingRun(
        string memory name,
        uint256 budget
    ) external returns (uint256) {
        trainingRunIdCount++;
        trainingRunStatuses[trainingRunIdCount] = ModelStatus.Registered;
        trainingRunNames[trainingRunIdCount] = name;
        trainingRunBudgets[trainingRunIdCount] = budget;
        return trainingRunIdCount;
    }

    /**
     * @dev Returns status of training run
     */
    function getTrainingRunStatus(uint256 trainingRunId) external view returns (ModelStatus) {
        return trainingRunStatuses[trainingRunId];
    }

    /**
     * @dev Returns the name of the training run.
     */
    function name(uint256 trainingRunId) public view virtual returns (string memory) {
        return trainingRunNames[trainingRunId];
    }

    /**
     * @dev Returns the budget for the training run
     */
    function budget(uint256 trainingRunId) public view virtual returns (uint256) {
        return trainingBudgets[trainingRunId];
    }

    /**
     * @dev Registers compute node for training run
     */
    function registerComputeNode(
        address account,
        string memory ipAddress,
        uint256 trainingRunId
    ) external returns (bool) {
        registeredComputeNodes[account] = ipAddress;
        registeredValidComputeNodes[account] = true;
        trainingRunComputeNodes[trainingRunId].push(account);
        return true;
    }

    /**
     * @dev Checks if a compute node has been added
     */
    function isComputeNodeValid(address account) external view returns (bool) {
        return registeredValidComputeNodes[account];
    }

    /**
     * @dev Starts training run
     */
    function startTrainingRun(uint256 trainingRunId) external returns (bool) {
        trainingRunStatuses[trainingRunId] = ModelStatus.Running;
        return true;
    }

    /**
     * @dev Submit attestation
     */
    function submitAttestation(
        address account,
        uint256 trainingRunId,
        bytes memory attestation
    ) external returns (bool) {
        // TODO: adjust this for many training runs + gas optimization
        bool doesTrainingRunContainNodeAddress = false;
        for (uint i = 0; i < trainingRunComputeNodes[trainingRunId].length; i++) {
            if (account == trainingRunComputeNodes[trainingRunId][i]) {
                doesTrainingRunContainNodeAddress = true;
                break;
            }
        }
        if (!doesTrainingRunContainNodeAddress) return false;
        computeAttestations[account].push(attestation);
        return true;
    }

    /**
     * @dev Returns addresses of compute nodes registered for a training run
     */
    function getComputeNodesForTrainingRun(uint256 trainingRunId) external view returns (address[] memory) {
        return trainingRunComputeNodes[trainingRunId];
    }

    /**
     * @dev Returns attestations of a compute node
     */
    function getAttestationsForComputeNode(address account) external view returns (bytes[] memory) {
        return computeAttestations[account];
    }

    /**
     * @dev Ends training run
     */
    function endTrainingRun(uint256 trainingRunId) external returns (bool) {
         trainingRunStatuses[trainingRunId] = ModelStatus.Done;
         emit EndTrainingRun(trainingRunId);
         return true;
    }

}
