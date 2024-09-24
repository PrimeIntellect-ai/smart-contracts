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

/// todo: Using (address account) for compute nodes instead of msg.sender

contract StakingManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SignedMath for uint256;

    // The Prime Intellect Network (PIN) token
    IERC20 public PIN;
    ITrainingManager public trainingManager;

    // 1 year of H100 hrs = 8760 PIN
    uint256 public MIN_DEPOSIT;

    // Mapping of compute node balances
    mapping(address => ComputeNodeInfo) public computeNodeBalances;

    // Mapping to track attestations per training run
    mapping(uint256 => uint256) public attestationsPerTrainingRun;

    // Constant for days after training run ends when rewards become claimable
    uint256 public constant CLAIM_DELAY_DAYS = 7;

    // Reward rate: 1 PIN per attestation
    uint256 public constant REWARD_RATE = 1;

    event Deposit(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event ChallengeSubmitted(uint256 indexed challengeId, uint256 indexed trainingRunId, address indexed challenger);
    event Slashed(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);

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

    struct ComputeNodeInfo {
        uint256 currentBalance; // PIN tokens not allocated to training run
        uint256 pendingRewards; // rewards owed by the protocol
        mapping(uint256 => uint256) attestationsPerRun; // trainingRunId => attestation count
        uint256[] participatedRuns;
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

        require(PIN.transferFrom(msg.sender, address(this), _amount), "Transfer of PIN failed");

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
    function challenge(uint256 trainingRunId, address computeNode) external whenNotPaused returns (uint256) {
        
        // get list of compute nodes for trainingRunId, check
        require(block.timestamp > runInfo.endTime, "Training run has not finished");
        require(block.timestamp <= runInfo.endTime + 7 days, "Challenge period has expired");
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

        PIN.safeTransfer(address(0), amount);

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
        uint256 totalPendingRewards
        
        for (uint256 i = 0; i < nodeInfo.participatedRuns.length; i++) {
            uint256 trainingRunId = nodeInfo.participatedRuns[i];
            (, uint256 runRewards) = calculateRunRewards(account, trainingRunId);
            totalPendingRewards += runRewards;
        }

        return totalPendingRewards;
    }

    /// Training hash more than 7 day past endTime
    /// Reward rate is fixed to one PIN per compute attestation
    /// Function is pauseable by Prime Intellect admin
    function claim() external nonReentrant {
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
