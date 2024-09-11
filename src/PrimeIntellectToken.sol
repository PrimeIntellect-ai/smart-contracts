// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PrimeIntellectManager.sol";

contract PrimeIntellectToken is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    PrimeIntellectManager public stakingManager;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function setStakingManager(
        address _stakingManager
    ) external onlyRole(ADMIN_ROLE) {
        stakingManager = PrimeIntellectManager(_stakingManager);
    }

    function mint(address to, uint256 amount) public onlyRole(ADMIN_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(ADMIN_ROLE) {
        _burn(from, amount);
    }

    function grantAdminRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    // Override the totalSupply function from ERC20 to make it public
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    /// @notice Stake PITokens to the PrimeIntellectManager contract
    /// @param amount Amount of PI tokens to stake
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(
            address(stakingManager) != address(0),
            "Staking manager not set"
        );

        // Transfer tokens from the user to the staking manager
        _transfer(msg.sender, address(stakingManager), amount);

        // Call the stake function on the staking manager
        stakingManager.stake(msg.sender, amount);
    }
}
