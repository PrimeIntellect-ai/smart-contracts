// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ComputeProviderManager is Ownable {
    mapping(address => bool) public whitelistedComputeProviders;

    event ComputeProviderWhitelisted(address indexed provider, bool status);

    function setComputeProviderStatus(
        address provider,
        bool status
    ) external onlyOwner {
        whitelistedComputeProviders[provider] = status;
        emit ComputeProviderWhitelisted(provider, status);
    }

    function isComputeProviderWhitelisted(
        address provider
    ) external view returns (bool) {
        return whitelistedComputeProviders[provider];
    }
}
