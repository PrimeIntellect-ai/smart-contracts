// contracts/Reward.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrimeToken is ERC20, Ownable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Should we hard code this to "PrimeToken", "PRIME"
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
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
}
