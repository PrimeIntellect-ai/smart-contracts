// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./PrimeIntellectToken.sol";
import "./TrainingManager.sol";
import "./interfaces/IStakingManager.sol";

contract StakingManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // The Prime Intellect Network (PIN) token
    PrimeIntellectToken public PIN;
    TrainingManager public trainingManager;

    // 1 year of H100 hrs = 8760 PIN
    uint256 public MIN_DEPOSIT;

    // Constant for days after training run ends when rewards become claimable
    uint256 public constant CLAIM_DELAY_DAYS = 7;

    // Reward rate: 1 PIN per attestation
    uint256 public constant REWARD_RATE = 1;

    struct ComputeBalancesInfo {
        uint256 currentBalance;
        mapping(uint256 => uint256) attestationsPerRun; // trainingRunId => attestation count
        uint256[] participatedRuns;
    }

    struct Challenge {
        uint256 trainingRunId;
        address challenger;
        bool resolved;
    }

    mapping(address => ComputeBalancesInfo) public computeNodeBalances; // Mapping of compute node balances
    mapping(uint256 => uint256) public attestationsPerTrainingRun; // Mapping to track attestations per training run
    mapping(uint256 => Challenge) public challenges;

    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event ChallengeSubmitted(uint256 indexed challengeId, uint256 indexed trainingRunId, address indexed challenger);
    event Slashed(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);
    event AttestationRecorded(address indexed account, uint256 trainingRunId);

    constructor(address _pinTokenAddress, address _trainingManagerAddress) {
        PIN = PrimeIntellectToken(_pinTokenAddress);
        require(_trainingManagerAddress != address(0), "Invalid TrainingManager address");
        trainingManager = TrainingManager(_trainingManagerAddress);
        MIN_DEPOSIT = 10000 * 10 ** 18; // 10,000 PIN token (assuming 18 decimals)
    }

    /////////////////////////////////////////
    ////           ADMIN FUNCTIONS        ///
    /////////////////////////////////////////

    function updateMinDeposit(uint256 _minDeposit) public onlyRole(DEFAULT_ADMIN_ROLE) {
        MIN_DEPOSIT = _minDeposit;
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    //////////////////////////////////////
    ////         STAKE & SLASH         ///
    //////////////////////////////////////

    /// @notice when a user deposits, we will check that user against whitelist.
    /// Only whitelisted Compute Nodes can stake.
    /// Balance associated to compute node address
    function stake(uint256 _amount) external nonReentrant {
        require(
            trainingManager.isComputeNodeValid(msg.sender),
            "Not on Compute Node whitelist"
        );
        require(_amount >= MIN_DEPOSIT, "Must be greater than min deposit");
        ComputeBalancesInfo storage balances = computeNodeBalances[msg.sender];

        // transfer PIN tokens to staking manager
        PIN.transferFrom(msg.sender, address(this), _amount);
        // increment PIN balance for compute node
        balances.currentBalance = balances.currentBalance + _amount;

        emit Staked(msg.sender, _amount);
    }

    /// @notice Withdraw staked PIN from PrimeIntellectManager
    /// @param _amount Amount of PIN tokens to withdraw
    function withdraw(uint256 _amount) external nonReentrant {
        ComputeBalancesInfo storage balances = computeNodeBalances[msg.sender];
        require(balances.currentBalance >= _amount, "Insufficient balance");

        balances.currentBalance = balances.currentBalance - _amount;

        require(PIN.transfer(msg.sender, _amount), "Transfer failed");

        emit Withdrawn(msg.sender, _amount);
    }

    /// @notice challenges posted for a specific training hash (compute provider & training run Id)
    /// Challenge is for notification purposes only at the moment.
    /// returns challengeId
    function challenge(
        uint256 _trainingRunId,
        address _computeNode
    ) external whenNotPaused returns (uint256) {
        require(
            trainingManager.getModelStatus(_trainingRunId) ==
                ITrainingManager.ModelStatus.Done,
            "Training run has not finished"
        );
        require(
            block.timestamp <=
                trainingManager.getTrainingRunEndTime(_trainingRunId) + 7 days,
            "Challenge period has expired"
        );

        uint256 challengeId = uint256(
            keccak256(
                abi.encodePacked(_trainingRunId, _computeNode, block.timestamp)
            )
        );
        challenges[challengeId] = Challenge({
            trainingRunId: _trainingRunId,
            challenger: msg.sender,
            resolved: false
        });

        emit ChallengeSubmitted(challengeId, _trainingRunId, msg.sender);
        return challengeId;
    }

    /// @notice slash is called by Prime Intellect admin.
    /// Slash amount is discretionary.
    /// sends staked PIN to 0x address (burn).
    function slash(
        address _account,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        ComputeBalancesInfo storage balances = computeNodeBalances[_account];
        uint256 totalBalance = balances.currentBalance;

        require(
            totalBalance >= _amount,
            "Slash amount exceeds total staked balance"
        );

        balances.currentBalance -= _amount;
        PIN.burn(_account, _amount);

        emit Slashed(_account, _amount);
    }

    /////////////////////////////////////////
    ////         REWARDS & CLAIMS         ///
    /////////////////////////////////////////

    /// @notice View function to see pending rewards on the frontend
    /// Pending rewards show up after training run ends
    /// Pending rewards include claimable and not-yet-claimable rewards
    function pendingRewards(address account) external view returns (uint256) {
        ComputeBalancesInfo storage nodeInfo = computeNodeBalances[account];
        uint256 totalPendingRewards = 0;

        for (uint256 i = 0; i < nodeInfo.participatedRuns.length; i++) {
            uint256 trainingRunId = nodeInfo.participatedRuns[i];
            (, uint256 runRewards) = calculateRunRewards(account, trainingRunId);
            totalPendingRewards += runRewards;
        }

        return totalPendingRewards;
    }

    /// @notice Helper function to calculate rewards for a single training run
    /// @param account The address of the compute node
    /// @param trainingRunId The ID of the training run
    /// @return isClaimable Whether the rewards are claimable
    /// @return rewards The amount of rewards for this training run
    function calculateRunRewards(address account, uint256 trainingRunId)
        internal
        view
        returns (bool isClaimable, uint256 rewards)
    {
        ComputeBalancesInfo storage nodeInfo = computeNodeBalances[account];
        uint256 attestationCount = nodeInfo.attestationsPerRun[trainingRunId];
        uint256 endTime = trainingManager.getTrainingRunEndTime(trainingRunId);

        isClaimable = block.timestamp > endTime + CLAIM_DELAY_DAYS * 1 days;
        rewards = attestationCount * REWARD_RATE;

        return (isClaimable, rewards);
    }

    /// @notice Claim function for compute nodes to claim their rewards
    /// @dev Rewards are only claimable after the CLAIM_DELAY_DAYS period has passed since the training run ended
    function claim() external nonReentrant whenNotPaused {
        // For the caller get array of participated runs and attestations per run.
        ComputeBalancesInfo storage nodeInfo = computeNodeBalances[msg.sender];
        // set counter
        uint256 totalRewards = 0;
        uint256 newLength = 0;

        // for each participated run, get training run id
        for (uint256 i = 0; i < nodeInfo.participatedRuns.length; i++) {
            uint256 trainingRunId = nodeInfo.participatedRuns[i];
            // use calculateRunRewards above to return rewards for that run
            (bool isClaimable, uint256 runRewards) = calculateRunRewards(msg.sender, trainingRunId);
            // if run rewards are claimable (over 7 days delay) then add run rewards to total rewards
            if (isClaimable) {
                totalRewards += runRewards;
                // delete keyword used to removed claimed attestations from the attestationsPerRun mapping
                delete nodeInfo.attestationsPerRun[trainingRunId];
            } else {
                // Keep unclaimed runs
                if (i != newLength) {
                    nodeInfo.participatedRuns[newLength] = nodeInfo.participatedRuns[i];
                }
                newLength++;
            }
        }

        require(totalRewards > 0, "No rewards available to claim");

        // Remove extra elements
        while (nodeInfo.participatedRuns.length > newLength) {
            nodeInfo.participatedRuns.pop();
        }
        // staking manager is approved minter on PIN token contract
        PIN.mint(msg.sender, totalRewards);

        emit RewardsClaimed(msg.sender, totalRewards);
    }

    /// @notice Can only be called by the StakingManager contract
    /// @dev Used to increment attestations balance for rewards accounting.
    function recordAttestation(address account, uint256 trainingRunId) external {
        require(msg.sender == address(trainingManager), "Only TrainingManager can record attestations");
        ComputeBalancesInfo storage nodeInfo = computeNodeBalances[account];
        nodeInfo.attestationsPerRun[trainingRunId]++;

        // If this is the first attestation for this run, add it to participatedRuns
        if (nodeInfo.attestationsPerRun[trainingRunId] == 1) {
            nodeInfo.participatedRuns.push(trainingRunId);
        }

        emit AttestationRecorded(account, trainingRunId);
    }

    ///////////////////////////////////////
    ////        GETTER FUNCTIONS        ///
    ///////////////////////////////////////

    /// @notice Get the balance of PIN tokens held by the staking contract
    /// @return The balance of PIN tokens held by this contract
    function getContractBalance() external view returns (uint256) {
        return PIN.balanceOf(address(this));
    }

    /// @notice Get the balance of PIN tokens staked by compute node account
    function getComputeNodeBalance(address account) external view returns (uint256) {
        return computeNodeBalances[account].currentBalance;
    }
}
