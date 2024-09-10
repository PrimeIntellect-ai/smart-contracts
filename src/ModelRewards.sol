// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PrimeToken.sol";

/// PrimeVault is a vault for Prime tokens.
/// Users can stake Prime tokens prior to a training run [future functionality: and be slashed].
/// The Prime Intellect protocol can allocate Prime tokens to the contract to be emitted as rewards.
/// Prime token stakers can allocate to a Prime model to share in rewards
/// [In the future stakers may want to trade model shares and/or receive rev share from model inference].

contract Rewards is AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amount; // How many Prime tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        // Users have two options when allocating to a model, they can stake or mint
        // pending reward = calculation to be added
        // 
    }

    // used in modelInfo[]: Stores information about each model.
    struct ModelInfo {
        // assetId for the model
        // how many allocation points assigned to this pool.
        // last block 
    }

    // The Prime Token
    PrimeToken public primeToken;
    // Owner address
    address public owner;
    // Info of each model
    ModelInfo[] public modelInfo;

    constructor(PrimeToken _primeToken, address _owner) public {
        primeToken = IERC20(_primeToken);
        transferOwnership(_owner);
    }

    function getModelCount() external view returns (uint256) {
        return modelInfo.length;
    }

    // Set reward variables for a model. Can only be called by the owner.
    // Model must be registered through the registration process.
    // By setting rewards, Prime Intellect indicates the model is approved.
    function setModelRewards(
        uint256 modelId,
        uint256 _allocPoint,
    ) public onlyOwner {
        // to be filled out
    }

    // Update reward variables for a model.
    function updateModelRewards(uint256 _modelId) {
        // function to update rewards.
    }
    

    // Deposit Prime tokens to a particular model for Prime rewards.
    function deposit(uint256 modelId, uint256 amount) external updateReward(msg.sender) {
        ModelInfo storage model = modelInfo[_modelId];
        // to be populated
    }
    

    function withdraw(uint256 _modelId, uint256 amount) external updateReward(msg.sender) {
        // check flag that user is able to withdraw
        // decrement amount from total staked to model
        // decrement balances[msg.sender] -= amount;
        // bool success = primeToken.transfer(msg.sender, amount);
        // if (!success) {
        // revert TransferFailed();}
    }

    function claimReward() updateReward(msg.sender) nonReentrant {
        // The contract is going to 
    }

}
