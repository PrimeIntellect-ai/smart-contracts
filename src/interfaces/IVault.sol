// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

interface IVault {
    // Events
    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 shares
    );
    event Claim(
        address indexed user,
        address indexed token,
        uint256 shares,
        uint256 amount
    );

    // Functions
    function deposit(address token, uint256 amount) external returns (uint256);
    function claim(address token, uint256 shares) external returns (uint256);
    function setBudget(address token, uint256 amount) external;
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4);
}
