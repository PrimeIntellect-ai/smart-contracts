// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "./interfaces/ITrainingManager.sol";
import "./StakingManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TrainingManager is ITrainingManager, AccessControl {
    StakingManager public stakingManager;

    struct ComputeNodeInfo {
        bytes[] attestations;
        uint256 index; // index in the computeNodesArray
    }

    struct TrainingRunInfo {
        mapping(address => ComputeNodeInfo) computeNodes;
        address[] computeNodesArray;
        uint256 endTime;
    }

    mapping(uint256 => TrainingRunInfo) internal trainingRunData;

    mapping(uint256 => ModelStatus) private trainingRunStatuses;
    mapping(uint256 => string) private trainingRunNames;
    mapping(uint256 => uint256) private trainingRunBudgets;
    mapping(address => string) private registeredComputeNodes;
    mapping(address => bool) private registeredValidComputeNodes;
    mapping(uint256 => address[]) private trainingRunComputeNodes;
    mapping(address => bytes[]) private computeAttestations;

    uint256 public trainingRunIdCount;

    event ComputeNodeAdded(address indexed account);
    event EndTrainingRun(uint256 trainingRunId, uint256 endTime);
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

    function joinTrainingRun(
        address account,
        string memory ipAddress,
        uint256 trainingRunId
    ) external returns (bool) {
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
     * @dev Returns status of training run
     */
    function getTrainingRunStatus(
        uint256 trainingRunId
    ) external view returns (ModelStatus) {
        return trainingRunStatuses[trainingRunId];
    }

    /**
     * @dev Registers compute node for training run
     */
    function addComputeNode(address account) external {
        require(account != address(0), "Invalid node address");
        require(
            !registeredValidComputeNodes[account],
            "Compute node already registered"
        );
        registeredValidComputeNodes[account] = true;

        emit ComputeNodeAdded(account);
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
    function startTrainingRun(
        uint256 trainingRunId
    ) external override returns (bool) {
        trainingRunStatuses[trainingRunId] = ModelStatus.Running;
        return true;
    }

    /**
     * @dev Ends training run
     */
    function endTrainingRun(uint256 trainingRunId) external returns (bool) {
        require(
            trainingRunStatuses[trainingRunId] == ModelStatus.Running,
            "Training run is not in Running state"
        );
        trainingRunStatuses[trainingRunId] = ModelStatus.Done;
        uint256 endTime = block.timestamp;
        trainingRunData[trainingRunId].endTime = endTime;
        emit EndTrainingRun(trainingRunId, endTime);
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
        // TODO: adjust this for many training runs + gas optimization
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

    function getAttestations(
        uint256 trainingRunId,
        address account
    ) external view returns (uint256) {
        require(
            trainingRunStatuses[trainingRunId] != ModelStatus.Registered,
            "Training run not started"
        );
        require(registeredValidComputeNodes[account], "Invalid compute node");

        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        ComputeNodeInfo storage nodeInfo = runInfo.computeNodes[account];

        bool isPartofRun = false;
        for (uint256 i = 0; i < runInfo.computeNodesArray.length; i++) {
            if (runInfo.computeNodesArray[i] == account) {
                isPartofRun = true;
                break;
            }
        }
        require(isPartofRun, "Compute node not part of run");

        return nodeInfo.attestations.length;
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

    function getTrainingRunEndTime(
        uint256 trainingRunId
    ) external view override returns (uint256) {
        require(
            trainingRunStatuses[trainingRunId] == ModelStatus.Done,
            "Training run has not ended"
        );
        return (trainingRunData[trainingRunId].endTime);
    }
}
