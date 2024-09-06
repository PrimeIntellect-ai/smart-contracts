// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {ITrainingManager} from "./interfaces/ITrainingManager.sol";

contract TrainingManager is ITrainingManager {

    mapping(string trainingRunId => TrainingRunStatus status) private trainingRunStatuses;
    mapping(address computeNodeAccount => string ipAddress) private registeredComputeNodes;
    mapping(string trainingRunId => address[] computeNodes) private trainingRunComputeNodes;
    mapping(address computeNodeAccount => bytes[] attestations) private computeAttestations;

    string private _name;
    uint256 private _budget;

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
    function symbol() public view virtual returns (uint256 memory) {
        return _budget;
    }

    function registerTrainingRun() external returns (string) {
        // generate unique string
        // add string to map
        // return string
    }

    function getTrainingRunStatus(string trainingRunId) external returns (TrainingRunStatus) {
        // read from map
    }

    function registerComputeNode(address account, string ipAddress, string trainingRunId) external returns (bool) {
        // add to account => ip map
        // add to trainingRunId => accountMap
    }

    function isComputeNodeValid(string ipAddress) external returns (bool) {
        // read from map
    }

    function startTrainingRun(string trainingRunId) external returns (bool) {
        // update status
    }

    function submitAttestation(address account, string trainingRunId, bytes attestation) external returns (bool) {
        // push bytes to list
    }

    function endTrainingRun(string trainingRunId) external returns (bool) {
        // update status
    }

}
