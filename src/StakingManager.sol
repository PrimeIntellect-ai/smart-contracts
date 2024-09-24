// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./PrimeIntellectToken.sol";
import "./TrainingManager.sol";

/// Compute nodes added to whitelist.
/// Compute nodes deposit/stake to the network. MIN deposit required.
/// Compute nodes will be required to maintain a minimum amount of Prime Intellect tokens staked to the network.
/// Compute nodes will be able to allocate their stake to training models.
/// Compute nodes can be slashed for providing fake or faulty attestation.
/// The Prime Intellect protocol can distribute PIN tokens to be claimed as rewards by compute providers.

contract StakingManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using SignedMath for uint256;

    // The Prime Intellect Network (PIN) token
    PrimeIntellectToken public PIN;
    ITrainingManager public trainingManager;

    // 1 year of H100 hrs = 8760 PIN
    uint256 public MIN_DEPOSIT;

    // Constant for days after training run ends when rewards become claimable
    uint256 public constant CLAIM_DELAY_DAYS = 7;

    // Reward rate: 1 PIN per attestation
    uint256 public constant REWARD_RATE = 1;

    mapping(address => ComputeNodeInfo) public computeNodeBalances; // Mapping of compute node balances
    mapping(uint256 => uint256) public attestationsPerTrainingRun; // Mapping to track attestations per training run
    mapping(uint256 => Challenge) public challenges;

    event Deposit(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event ChallengeSubmitted(
        uint256 indexed challengeId,
        uint256 indexed trainingRunId,
        address indexed challenger
    );
    event Slashed(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);

    struct ComputeNodeInfo {
        uint256 currentBalance; // PIN tokens not allocated to training run
        uint256 pendingRewards; // rewards owed by the protocol
        mapping(uint256 => uint256) attestationsPerRun; // trainingRunId => attestation count
        uint256[] participatedRuns;
    }

    struct Challenge {
        uint256 trainingRunId;
        address challenger;
        bool resolved;
    }

    constructor(
        PrimeIntellectToken _pin,
        ITrainingManager _trainingManager,
        uint256 _initialMinDeposit
    ) {
        PIN = _pin;
        trainingManager = _trainingManager;
        MIN_DEPOSIT = _initialMinDeposit;
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /////////////////////////////////////////
    ////           ADMIN FUNCTIONS        ///
    /////////////////////////////////////////

    function updateMinDeposit(
        uint256 _minDeposit
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        MIN_DEPOSIT = _minDeposit;
    }

    modifier onlyRegisteredComputeNode(address account) {
        require(
            trainingManager.isComputeNodeValid(account),
            "Account not on Compute Node whitelist"
        );
        _;
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
    function stake(
        address account,
        uint256 _amount
    ) external nonReentrant onlyRegisteredComputeNode(account) {
        require(
            _amount >= MIN_DEPOSIT,
            "Deposit amount must be greater than minimum deposit"
        );
        ComputeNodeInfo storage balances = computeNodeBalances[account];

        require(
            PIN.transferFrom(msg.sender, address(this), _amount),
            "Transfer of PIN failed"
        );

        balances.currentBalance = balances.currentBalance + _amount;

        emit Deposit(account, _amount);
    }

    /// @notice Withdraw staked PIN from PrimeIntellectManager
    /// @param _amount Amount of PIN tokens to withdraw
    function withdraw(uint256 _amount) external nonReentrant {
        ComputeNodeInfo storage balances = computeNodeBalances[msg.sender];
        require(balances.currentBalance >= _amount, "Insufficient balance");

        balances.currentBalance = balances.currentBalance - _amount;

        require(PIN.transfer(msg.sender, _amount), "Transfer failed");

        emit Withdrawn(msg.sender, _amount);
    }

    /// @notice Only model owner can submit on-chain challenge.
    /// challenges posted for a specific training hash (compute provider & training run Id)
    /// can only be called by `model_owner`
    /// returns challengeId
    function challenge(
        uint256 trainingRunId,
        address computeNode
    ) external whenNotPaused returns (uint256) {
        require(
            trainingManager.getModelStatus(trainingRunId) ==
                ITrainingManager.ModelStatus.Done,
            "Training run has not finished"
        );
        require(
            block.timestamp <=
                trainingManager.getTrainingRunEndTime(trainingRunId) + 7 days,
            "Challenge period has expired"
        );

        uint256 challengeId = uint256(
            keccak256(
                abi.encodePacked(trainingRunId, computeNode, block.timestamp)
            )
        );
        challenges[challengeId] = Challenge({
            trainingRunId: trainingRunId,
            challenger: msg.sender,
            resolved: false
        });

        emit ChallengeSubmitted(challengeId, trainingRunId, msg.sender);
        return challengeId;
    }

    /// @notice slash is called by Prime Intellect admin.
    /// Slash amount is discretionary.
    /// sends staked PIN to 0x address (burn)
    function slash(
        address account,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        ComputeNodeInfo storage balances = computeNodeBalances[account];
        uint256 totalBalance = balances.currentBalance;

        require(
            totalBalance >= amount,
            "Slash amount exceeds total staked balance"
        );

        balances.currentBalance -= amount;
        PIN.burn(amount);

        emit Slashed(account, amount);
    }

    /////////////////////////////////////////
    ////         REWARDS & CLAIMS         ///
    /////////////////////////////////////////

    /// @notice View function to see pending rewards on the frontend
    /// Pending rewards show up after training run ends
    /// Pending rewards include claimable and not-yet-claimable rewards
    function pendingRewards(address account) external view returns (uint256) {
        ComputeNodeInfo storage nodeInfo = computeNodeBalances[account];
        uint256 totalPendingRewards = 0;

        for (uint256 i = 0; i < nodeInfo.participatedRuns.length; i++) {
            uint256 trainingRunId = nodeInfo.participatedRuns[i];
            (, uint256 runRewards) = calculateRunRewards(
                account,
                trainingRunId
            );
            totalPendingRewards += runRewards;
        }

        return totalPendingRewards;
    }

    /// @notice Helper function to calculate rewards for a single training run
    /// @param account The address of the compute node
    /// @param trainingRunId The ID of the training run
    /// @return isClaimable Whether the rewards are claimable
    /// @return rewards The amount of rewards for this training run
    function calculateRunRewards(
        address account,
        uint256 trainingRunId
    ) internal view returns (bool isClaimable, uint256 rewards) {
        ComputeNodeInfo storage nodeInfo = computeNodeBalances[account];
        uint256 attestationCount = nodeInfo.attestationsPerRun[trainingRunId];
        uint256 endTime = trainingManager.getTrainingRunEndTime(trainingRunId);

        isClaimable = block.timestamp > endTime + CLAIM_DELAY_DAYS * 1 days;
        rewards = attestationCount * REWARD_RATE;

        return (isClaimable, rewards);
    }

    /// @notice Claim function for compute nodes to claim their rewards
    /// @dev Rewards are only claimable after the CLAIM_DELAY_DAYS period has passed since the training run ended
    function claim() external nonReentrant whenNotPaused {
        ComputeNodeInfo storage nodeInfo = computeNodeBalances[msg.sender];
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < nodeInfo.participatedRuns.length; i++) {
            uint256 trainingRunId = nodeInfo.participatedRuns[i];
            (bool isClaimable, uint256 runRewards) = calculateRunRewards(
                msg.sender,
                trainingRunId
            );

            if (isClaimable) {
                totalRewards += runRewards;
                delete nodeInfo.attestationsPerRun[trainingRunId];
            }
        }

        require(totalRewards > 0, "No rewards available to claim");

        // Remove claimed runs from the participated runs array
        uint256[] memory newParticipatedRuns = new uint256[](
            nodeInfo.participatedRuns.length
        );
        uint256 newIndex = 0;
        for (uint256 i = 0; i < nodeInfo.participatedRuns.length; i++) {
            uint256 trainingRunId = nodeInfo.participatedRuns[i];
            if (nodeInfo.attestationsPerRun[trainingRunId] > 0) {
                newParticipatedRuns[newIndex] = trainingRunId;
                newIndex++;
            }
        }
        nodeInfo.participatedRuns = newParticipatedRuns;
        nodeInfo.participatedRuns.length = newIndex;

        // Mint new PIN tokens as rewards
        PIN.mint(msg.sender, totalRewards);

        emit RewardsClaimed(msg.sender, totalRewards);
    }

    /////////////////////////////////////////
    ////          GETTER FUNCTIONS        ///
    /////////////////////////////////////////

    /// @notice Get the balance of PIN tokens held by the staking contract
    /// @return The balance of PIN tokens held by this contract
    function getContractBalance() external view returns (uint256) {
        return PIN.balanceOf(address(this));
    }
}
