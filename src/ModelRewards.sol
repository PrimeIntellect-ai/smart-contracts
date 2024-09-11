// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PrimeToken.sol";

/// Compute nodes will be required to maintain a minimum amount of PRIME tokens staked to the network.
/// Compute nodes will be able to allocate their stake to training models.
/// Compute nodes can be slashed for providing fake or faulty attestation.
/// The Prime Intellect protocol can allocate prime intellect tokens to the contract to be emitted as rewards.
/// Compute contributors can claim additional prime intellect tokens.

contract PrimeIntellect is AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amountStaked; // How many Prime tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        // Flow for staking:
        //  1. Owner adds model to Reward contract, set rewards variables
        //  2. User stakes Prime token to model
        //  3. Contract gets 'modelFinished' event
        //  4. Calculate rewards
    }

    // used in modelInfo[]: Stores information about each model.
    struct ModelInfo {
        uint256 modelId; // assetId for the model
        uint256 maxReward; // max reward amount for training run.
        uint256 attestCount; // number of attestations recorded for model
        uint256 accPrimePerAttest; // accumulated Prime per attestation
        bool fundsfrozen; // flag to indicate if user can deposit/withdraw
    }

    ModelInfo public _modelInfo;

    // The Prime Token
    PrimeToken public primeToken;
    // Owner address
    address public owner;
    // Info of each model
    ModelInfo[] public modelInfo;
    // Info of each compute provider that stakes Prime tokens.
    mapping(uint256 => mapping(address => UserInfo)) userInfo;
    // Hours to Tokens multipler
    uint256 public COMPUTE_MULTIPLIER = 200;
    // state variable for USD
    uint256 public USD = 100;
    // min amount staked to begin training run.
    // @dev minStakedAmount should be a percentage of maxRewards
    uint256 public minStaked;
    // max reward tokens
    uint256 public MAX_REWARD_MULTIPLIER


    constructor(PrimeToken _primeToken, address _owner, uint256 _budgetHours) {
        primeToken = IERC20(_primeToken);
        transferOwnership(_owner);
        budgetHours = _budgetHours:
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        updateMinStaked();
    }

    function getmodels() external view returns (uint256) {
        return modelInfo.length;
    }

    function updateMinStaked() public onlyRole(DEFAULT_ADMIN_ROLE) {
        minStaked = budgetHours.mul(COMPUTE_MULTIPLIER).div(USD);
    }

    function setComputeMultipier(uint256 _computeMultiplier) public onlyRole(DEFAULT_ADMIN_ROLE) {
        COMPUTE_MULTIPLIER = _computeMultiplier;
        updateMinStaked();
    }

    // Set reward variables for a model. Can only be called by the owner.
    // Model must be registered through the registration process.
    // By setting rewards, Prime Intellect indicates the model is approved.
    function ApproveForRewards(
        uint256 modelId
    ) public onlyOwner(DEFAULT_ADMIN_ROLE) {
        // Set minimum stake
        // Hours budget * compute_multiplier = maxRewards
        uint256 maxReward = multiplier.mul(budgetAmount);
        // Set minimum amount to stake
        // implement function to set custom minimum per model. For now global variable.
        modelInfo.push(
            ModelInfo({
                modelId: _modelId,
                maxReward: maxReward,
                attestCount: attestationCount,
                accPrimePerAttest: 0,
            })
        )
    }

    min

    // Update reward variables for a model.
    function setModelRewards(uint256 _modelId) public {
        ModelInfo storage model = modelInfo[_modelId];
    }


    // Deposit Prime tokens to a particular model for Prime rewards.
    function StakeToModel(uint256 modelId, uint256 amount, address to) public {
        // check flag that user is able to deposit
        ModelInfo memory model
        primeTokenSupply += amount;
        primeTokenBalances[msg.sender] += amount;
        emit Staked(msg.sender, amount);
        bool success = primeToken.safeTransferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }
    }


    function withdraw(uint256 _modelId, uint256 amount) external updateReward(msg.sender) {
        // check flag that user is able to withdraw
        primeTotalSupply -= amount;
        primeTokenBalances[msg.sender] -= amount;
        emit WithdrewStake(msg.sender, amount);
        bool success = primeToken.transfer(msg.sender, amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    function claimReward() external updateReward(msg.sender) nonReentrant {
        // The contract is going to 
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }

    function getModelBudget(uint256 modelId) public view returns (uint256) {
        returns budget[modelId];
    }

}