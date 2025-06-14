// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IWorkValidation {
    function submitWork(uint256 _domainId, uint256 poolId, address provider, address nodeId, bytes calldata data)
        external
        returns (bool, uint256);

    function invalidateWork(uint256 poolId, bytes calldata data) external returns (address, address);

    function softInvalidateWork(uint256 poolId, bytes calldata data) external returns (address, address, uint256);
}
