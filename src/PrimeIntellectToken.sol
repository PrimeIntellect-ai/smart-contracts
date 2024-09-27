// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PrimeIntellectToken is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
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

    function revokeMinterRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    // Override the totalSupply function from ERC20 to make it public
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }
}
