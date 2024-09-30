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
        string name;
        uint256 budget;
        ModelStatus status;
        address[] computeNodesArray;
        mapping(address => ComputeNodeInfo) computeNodes;
        uint256 endTime;
    }

    mapping(uint256 => TrainingRunInfo) public trainingRunData;
    mapping(address => bool) public registeredValidComputeNodes;
    mapping(address => string) public registeredComputeNodes;

    uint256 public trainingRunIdCount;

    event ComputeNodeAdded(address indexed account);
    event TrainingRunEnded(uint256 trainingRunId, uint256 endTime);
    event AttestationSubmitted(
        address indexed computeNode,
        uint256 trainingRunId
    );
    event StakingManagerSet(address stakingManager);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setStakingManager(
        address _stakingManagerAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _stakingManagerAddress != address(0),
            "Invalid StakingManager address"
        );
        stakingManager = StakingManager(_stakingManagerAddress);
        emit StakingManagerSet(_stakingManagerAddress);
    }

    //////////////////////////////////////
    ////           MODEL SETUP        ///
    /////////////////////////////////////

    // todo: add require statement for duplication name/budget combination
    function registerModel(
        string memory _name,
        uint256 _budget
    ) external override returns (uint256) {
        trainingRunIdCount++;
        TrainingRunInfo storage newRun = trainingRunData[trainingRunIdCount];
        newRun.status = ModelStatus.Registered;
        newRun.name = _name;
        newRun.budget = _budget;
        return trainingRunIdCount;
    }

    /// @notice returns status of training run
    function getModelStatus(
        uint256 trainingRunId
    ) external view returns (ModelStatus) {
        return trainingRunData[trainingRunId].status;
    }

    /// @notice returns the name of the training run
    function name(
        uint256 trainingRunId
    ) public view override returns (string memory) {
        return trainingRunData[trainingRunId].name;
    }

    /// @notice Returns the budget for the training run
    function budget(
        uint256 trainingRunId
    ) public view override returns (uint256) {
        return trainingRunData[trainingRunId].budget;
    }

    /// @notice returns status for the model regarding the training run
    /// @dev Model statuses are defined in ITrainingManager.sol
    function getTrainingRunStatus(
        uint256 trainingRunId
    ) external view returns (ModelStatus) {
        return trainingRunData[trainingRunId].status;
    }

    /////////////////////////////////////
    ////         TRAINING RUN         ///
    /////////////////////////////////////

    /// @notice Adds compute node to list of compute providers for training run
    /// @param account wallet address of compute node
    /// @param ipAddress ip address that will be associated with compute attestations
    /// @param trainingRunId the id for the training run
    function joinTrainingRun(
        address account,
        string memory ipAddress,
        uint256 trainingRunId
    ) external returns (bool) {
        require(
            address(stakingManager) != address(0),
            "StakingManager not set"
        );
        require(
            stakingManager.getComputeNodeBalance(account) >=
                stakingManager.MIN_DEPOSIT(),
            "Insufficient staked balance"
        );
        require(bytes(ipAddress).length > 0, "IP address cannot be empty");

        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        require(
            runInfo.status == ModelStatus.Registered,
            "Invalid training run status"
        );

        for (uint256 i = 0; i < runInfo.computeNodesArray.length; i++) {
            require(
                runInfo.computeNodesArray[i] != account,
                "Compute node already joined training run"
            );
        }
        require(
            // checks the node's index is 0, default value
            runInfo.computeNodes[account].index == 0 &&
                (runInfo.computeNodesArray.length == 0 ||
                    runInfo.computeNodesArray[0] != account),
            "Compute node already in training run"
        );

        runInfo.computeNodesArray.push(account);
        runInfo.computeNodes[account].index =
            runInfo.computeNodesArray.length -
            1;

        registeredValidComputeNodes[account] = true;
        return true;
    }

    /// @dev Adds compute node to whitelist of valid compute nodes
    function addComputeNode(address account) external {
        require(account != address(0), "Invalid node address");
        require(
            !registeredValidComputeNodes[account],
            "Compute node already registered"
        );
        registeredValidComputeNodes[account] = true;

        emit ComputeNodeAdded(account);
    }

    /// @dev Checks if a compute node has been added
    function isComputeNodeValid(address account) external view returns (bool) {
        return registeredValidComputeNodes[account];
    }

    /// @dev Starts training run
    /// must be Prime Intellect admin
    function startTrainingRun(
        uint256 trainingRunId
    ) external override returns (bool) {
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        require(
            runInfo.status == ModelStatus.Registered,
            "Invalid training run status"
        );
        runInfo.status = ModelStatus.Running;
        return true;
    }

    /// @notice Called by compute nodes to end training run
    /// Prime Intellect admin
    function endTrainingRun(uint256 trainingRunId) external returns (bool) {
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        require(
            runInfo.status == ModelStatus.Running,
            "Training run is not in Running state"
        );
        runInfo.status = ModelStatus.Done;
        runInfo.endTime = block.timestamp;
        emit TrainingRunEnded(trainingRunId, runInfo.endTime);
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
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        require(
            runInfo.status == ModelStatus.Running,
            "Training run is not active"
        );

        ComputeNodeInfo storage nodeInfo = runInfo.computeNodes[account];
        require(
            nodeInfo.index < runInfo.computeNodesArray.length,
            "Compute node not part of this training run"
        );

        nodeInfo.attestations.push(attestation);
        stakingManager.recordAttestation(account, trainingRunId);

        emit AttestationSubmitted(account, trainingRunId);
        return true;
    }

    function getAttestations(
        uint256 trainingRunId,
        address account
    ) external view returns (uint256) {
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        require(
            runInfo.status != ModelStatus.Registered,
            "Training run not started"
        );
        require(registeredValidComputeNodes[account], "Invalid compute node");

        ComputeNodeInfo storage nodeInfo = runInfo.computeNodes[account];
        require(
            nodeInfo.index < runInfo.computeNodesArray.length,
            "Compute node not part of run"
        );

        return nodeInfo.attestations.length;
    }

    /**
     * @dev Returns addresses of compute nodes registered for a training run
     */
    function getComputeNodesForTrainingRun(
        uint256 trainingRunId
    ) external view returns (address[] memory) {
        return trainingRunData[trainingRunId].computeNodesArray;
    }

    /**
     * @dev Returns attestations of a compute node
     */
    function getAttestationsForComputeNode(
        uint256 trainingRunId,
        address account
    ) external view returns (bytes[] memory) {
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        ComputeNodeInfo storage nodeInfo = runInfo.computeNodes[account];
        require(
            nodeInfo.index < runInfo.computeNodesArray.length,
            "Compute node not part of this training run"
        );

        return nodeInfo.attestations;
    }

    function getTrainingRunInfo(
        uint256 trainingRunId
    )
        external
        view
        returns (
            string memory _name,
            uint256 _budget,
            ModelStatus status,
            address[] memory computeNodes
        )
    {
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        return (
            runInfo.name,
            runInfo.budget,
            runInfo.status,
            runInfo.computeNodesArray
        );
    }

    function getTrainingRunEndTime(
        uint256 trainingRunId
    ) external view override returns (uint256) {
        TrainingRunInfo storage runInfo = trainingRunData[trainingRunId];
        require(
            runInfo.status == ModelStatus.Done,
            "Training run has not ended"
        );
        return runInfo.endTime;
    }
}
