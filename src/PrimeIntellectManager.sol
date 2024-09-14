// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PrimeIntellectToken.sol";

/// Compute nodes will be required to maintain a minimum amount of Prime Intellect tokens staked to the network.
/// Compute nodes will be able to allocate their stake to training models.
/// Compute nodes can be slashed for providing fake or faulty attestation.
/// The Prime Intellect protocol can allocate prime intellect tokens to the contract to be emitted as rewards.
/// Compute contributors can claim additional prime intellect tokens.

contract PrimeIntellectManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SignedMath for uint256;

    // The Prime Intellect Token
    IERC20 public PIToken;
    // Owner address
    address public owner;
    // Total staked amount
    uint256 public totalStaked;
    // Mapping of user addresses to their staked amount
    mapping(address => uint256) public stakedBalance;
    // Compute hours to native token exchange rate
    uint256 public COMPUTE_MULTIPLIER = 200;
    // minimum staking amount to be valid compute node
    // 1 year of H100 hours = 8760 hr = 525,600 min
    uint256 public minStake;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(IERC20 _PIToken, address _owner, uint256 _minStake) {
        PIToken = _PIToken;
        owner = _owner;
        minStake = _minStake;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    struct AccountInfo {
        uint256 amountStaked; // How many Prime tokens the user has staked.
        uint256 pendingRewards; // Rewards owed by the protocol.
    }

    /////////////////////////////////////////
    ////           ADMIN FUNCTIONS        ///
    /////////////////////////////////////////

    function updateMinStake(
        uint256 _minStake
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        minStake = _minStake;
    }

    // slash - user being slashed, amount, and challengeId associated
    // slash can only be called by Admin/owner
    // function slash(address account, uint256 amount) {}

    // minStake = 1000. stakedBalance = 2000. ComputeNode[id]
    // canRegisterForTrainingRun = stakedBalance[id] > minStake[id]

    /////////////////////////////////////////
    ////          USER FUNCTIONS          ///
    /////////////////////////////////////////

    /// @notice Stake PITokens to PrimeIntellectManager
    /// @param _amount Amount of PI tokens to stake
    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            PIToken.allowance(msg.sender, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // Transfer Prime Intellect tokens from the user to this contract
        PIToken.safeTransferFrom(msg.sender, address(this), _amount);

        stakedBalance[msg.sender] = stakedBalance[msg.sender] + _amount;
        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    /// @notice Withdraw staked PITokens from PrimeIntellectManager
    /// @param _amount Amount of PI tokens to withdraw
    // Dev: consider adding Reentrancy protection
    // function withdraw(uint256 _amount) external nonReentrant {
    //     require(_amount > 0, "Amount must be greater than 0");
    //     require(
    //         PIToken.allowance(msg.sender) >= _amount,
    //         "Insufficient staked balance"
    //     );

    //     // Update the user's staked balance
    //     stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(_amount);
    //     // Update the total staked amount
    //     totalStaked = totalStaked.sub(_amount);

    //     // Transfer the tokens back to the user
    //     require(PIToken.transfer(msg.sender, _amount), "Token transfer failed");

    //     emit Withdrawn(msg.sender, _amount);
    // }

    /// @notice model trainers able to submit on-chain challenge
    /// function challenge(uint256 modelId)

    /////////////////////////////////////////
    ////          GETTER FUNCTIONS          ///
    /////////////////////////////////////////

    /// @notice Get the staked balance of a user
    /// @param _user Address of the user
    /// @return The staked balance of the user
    function getStakedBalance(address _user) external view returns (uint256) {
        return stakedBalance[_user];
    }

    /// @notice Get the total staked amount
    /// @return The total staked amount
    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }
}
