// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {ITrainingManager} from "./interfaces/ITrainingManager.sol";
import {StakingManager} from "./StakingManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TrainingManager is ITrainingManager, StakingManager, AccessControl {
    StakingManager public stakingManager;

    mapping(uint256 trainingRunId => ModelStatus status)
        private trainingRunStatuses;
    mapping(uint256 trainingRunId => string name) private trainingRunNames;
    mapping(uint256 trainingRunId => uint256 budget) private trainingRunBudgets;
    mapping(address computeNodeAccount => string ipAddress)
        private registeredComputeNodes;
    mapping(address computeNodeAccount => bool validNode)
        private registeredValidComputeNodes;
    mapping(uint256 trainingRunId => address[] computeNodes)
        private trainingRunComputeNodes;
    mapping(address computeNodeAccount => bytes[] attestations)
        private computeAttestations;

    mapping(bytes32 => TrainingRunInfo) public trainingRuns;
    mapping(address => bytes32[]) public computeNodeTrainingHashes;

    uint256 public trainingRunIdCount;

    event EndTrainingRun(uint256 trainingRunId);
    event AttestationSubmitted(
        address indexed computeNode,
        uint256 trainingRunId
    );

    struct TrainingRunInfo {
        uint256 trainingRunId;
        address computeNode;
        string ipAddress;
    }

    //////////////////////////////////////
    ////           MODEL OWNERS        ///
    //////////////////////////////////////

    ///@dev Initializes a new model
    function registerModel(
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
    function getTrainingRunStatus(
        uint256 trainingRunId
    ) external view returns (ModelStatus) {
        return trainingRunStatuses[trainingRunId];
    }

    /**
     * @dev Returns the name of the training run.
     */
    function name(
        uint256 trainingRunId
    ) public view virtual returns (string memory) {
        return trainingRunNames[trainingRunId];
    }

    /**
     * @dev Returns the budget for the training run
     */
    function budget(
        uint256 trainingRunId
    ) public view virtual returns (uint256) {
        return trainingBudgets[trainingRunId];
    }

    //////////////////////////////////////
    ////      COMPUTE PROVIDERS        ///
    //////////////////////////////////////

    function isComputeNodeValid(address account) public view returns (bool) {
        bool computeNodeIsRegistered = registeredComputeNodes[account];
        return computeNodeIsRegistered;
    }

    /**
     * @dev Registers compute node for training run
     * @notice Compute node must have at least minimum PIN staked
     */
    function joinTrainingRun(
        address account,
        string memory ipAddress,
        uint256 trainingRunId
    ) external returns (bool) {
        // check that account has minimum staked
        require(
            stakingManager.getTotalBalance(account) >=
                stakingManager.MIN_DEPOSIT(),
            "Insufficent staked balance"
        );
        require(string(ipAddress).length > 0, "IP address cannot be empty");

        registeredComputeNodes[account] = ipAddress;
        registeredValidComputeNodes[account] = true;
        trainingRunComputeNodes[trainingRunId].push(account);
        return true;
    }

    // to be deleted.
    // function isComputeNodeValid(address account) external returns (bool) {
    //     if (registeredComputeNodes[account].isValue) return true;
    //     return false;
    // }

    function submitAttestation(
        address account,
        uint256 trainingRunId,
        bytes memory attestation
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

    /**
     * @dev Returns addresses of compute nodes registered for a training run
     */
    function getComputeNodesForTrainingRun(
        uint256 trainingRunId
    ) external view returns (address[] memory) {
        return trainingRunComputeNodes[trainingRunId];
    }

    /**
     * @dev Returns attestations of a compute node
     */
    function getAttestationsForComputeNode(
        address account
    ) external view returns (bytes[] memory) {
        return computeAttestations[account];
    }

    function startTrainingRun(uint256 trainingRunId) external returns (bool) {
        trainingRunStatuses[trainingRunId] = TrainingRunStatus.Running;
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
