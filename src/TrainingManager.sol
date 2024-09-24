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

    mapping(uint256 trainingRunId => ModelStatus status) private trainingRunStatuses;
    mapping(uint256 trainingRunId => string name) private trainingRunNames;
    mapping(uint256 trainingRunId => uint256 budget) private trainingRunBudgets;
    mapping(address computeNodeAccount => string ipAddress) private registeredComputeNodes;
    mapping(address computeNodeAccount => bool validNode) private registeredValidComputeNodes;
    mapping(uint256 trainingRunId => address[] computeNodes) private trainingRunComputeNodes;
    mapping(address computeNodeAccount => bytes[] attestations) private computeAttestations;

    uint256 public trainingRunIdCount;


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

    ) external override returns (bool) {

    ) external returns (bool) {
        // TODO: adjust this for many training runs + gas optimization
main
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
main
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
