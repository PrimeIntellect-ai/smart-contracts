// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PrimeToken.sol";

/// Users can stake Prime tokens prior to a training run [future functionality: and be slashed].
/// The Prime Intellect protocol can allocate Prime tokens to the contract to be emitted as rewards.
/// Prime token stakers can allocate to a Prime model to share in rewards
/// [In the future stakers may want to trade model shares and/or receive rev share from model inference].

contract Rewards is AccessControl {
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
    // min amount staked to begin training run.
    // @dev minStakedAmount should be a percentage of maxRewards
    uint256 public minStakedAmount = 8;
    // max reward tokens
    uint256 public MAX_REWARDS
    

    constructor(PrimeToken _primeToken, address _owner) public {
        primeToken = IERC20(_primeToken);
        transferOwnership(_owner);
    }

    function getmodels() external view returns (uint256) {
        return modelInfo.length;
    }

    // Set reward variables for a model. Can only be called by the owner.
    // Model must be registered through the registration process.
    // By setting rewards, Prime Intellect indicates the model is approved.
    function AddRewardsToModel(
        uint256 modelId,
        uint256 budgetAmount,
    ) public onlyOwner {
        // Hours budget * compute_multiplier = maxRewards
        uint256 maxReward = multiplier.mul(budgetAmount);
        // Set minimum amount to stake
        // implement function to set custom minimum per model. For now global variable.
        modelInfo.push(
            ModelInfo({
                modelId: _modelId,
                maxReward: maxReward,
                attestCount: attestationCount,
                accPrimePerAttest: 0
            })
        )
    }

    // Update reward variables for a model.
    function setModelRewards(uint256 _modelId) public {
        ModelInfo storage model = modelInfo[_modelId];
    }
    

    // Deposit Prime tokens to a particular model for Prime rewards.
    function deposit(uint256 modelId, uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
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
        s_totalSupply -= amount;
        s_balances[msg.sender] -= amount;
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