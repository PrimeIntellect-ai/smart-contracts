// SPDX-License-Identifier:

pragma solidity >=0.8.0;

interface IPrimeVaultFactory {
    /// @notice Returns the address of the current owner
    function owner() external view returns (address);

    function vaultIdCount() external view returns (uint256);

    function idToVehicle(uint256 id_) external view returns (address);

    function createVault() external returns (address);

    function getUserVault(address user) external view returns (address);

    //    function deployVehicle(
    //        string memory vaultName_,
    //        address owner_,
    //        address guardian_
    //    ) external returns (address vault_, uint256 id_);
}
