// SPDX-License-Identifier:

pragma solidity >=0.8.0;

interface IVaultRegister {
    // Events
    event VaultCreated(address indexed owner, address vaultAddress);

    /// @notice Returns the address of the current owner
    function owner() external view returns (address);

    function vaultIdCount() external view returns (uint256);

    function idToVault(uint256 id_) external view returns (address);

    function createVault() external returns (address);

    function getUserVault(address user) external view returns (address);
}
