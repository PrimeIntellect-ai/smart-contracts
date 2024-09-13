// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PrimeIntellectToken.sol";

/// Compute nodes will be required to maintain a minimum amount of Prime Intellect tokens staked to the network.
/// Compute nodes will be able to allocate their stake to training models.
/// Compute nodes can be slashed for providing fake or faulty attestation.
/// The Prime Intellect protocol can allocate prime intellect tokens to the contract to be emitted as rewards.
/// Compute contributors can claim additional prime intellect tokens.

contract PrimeIntellectManager is AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // The Prime Intellect Token
    PrimeIntellectToken public PIToken;
    // Owner address
    address public owner;
    // Total staked amount
    uint256 public totalStaked;
    // Mapping of user addresses to their staked amount
    mapping(address => uint256) public stakedBalance;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(PrimeIntellectToken _PIToken, address _owner) {
        PIToken = _PIToken;
        owner = _owner;
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /// @notice Stake PITokens to PrimeIntellectManager
    /// @param _user Address of the user staking tokens
    /// @param _amount Amount of PI tokens to stake
    function stake(address _user, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            msg.sender == address(PIToken),
            "Only PIToken contract can call this function"
        );

        // Update the user's staked balance
        stakedBalance[_user] = stakedBalance[_user].add(_amount);
        // Update the total staked amount
        totalStaked = totalStaked.add(_amount);

        emit Staked(_user, _amount);
    }

    /// @notice Withdraw staked PITokens from PrimeIntellectManager
    /// @param _amount Amount of PI tokens to withdraw
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            stakedBalance[msg.sender] >= _amount,
            "Insufficient staked balance"
        );

        // Update the user's staked balance
        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(_amount);
        // Update the total staked amount
        totalStaked = totalStaked.sub(_amount);

        // Transfer the tokens back to the user
        require(PIToken.transfer(msg.sender, _amount), "Token transfer failed");

        emit Withdrawn(msg.sender, _amount);
    }

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
