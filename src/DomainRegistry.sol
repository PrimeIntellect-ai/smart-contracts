// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IDomainRegistry.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract DomainRegistry is IDomainRegistry, AccessControlEnumerable {
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE");

    Domain[] public domains;

    constructor(address primeAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, primeAdmin);
        _grantRole(PRIME_ROLE, primeAdmin);
    }

    function create(
        string calldata name,
        IComputePool computePool,
        IWorkValidation validationContract,
        string calldata domainParametersURI
    ) external onlyRole(PRIME_ROLE) returns (uint256) {
        Domain memory domain = Domain({
            domainId: domains.length,
            name: name,
            validationLogic: validationContract,
            domainParametersURI: domainParametersURI,
            computePool: computePool
        });

        domains.push(domain);

        emit DomainCreated(name, domain.domainId, address(validationContract), domainParametersURI);

        return domain.domainId;
    }

    function updateValidationLogic(uint256 domainId, address validationContract) external onlyRole(PRIME_ROLE) {
        domains[domainId].validationLogic = IWorkValidation(validationContract);

        emit DomainUpdated(domainId, validationContract, domains[domainId].domainParametersURI);
    }

    function updateParameters(uint256 domainId, string calldata domainParametersURI) external onlyRole(PRIME_ROLE) {
        domains[domainId].domainParametersURI = domainParametersURI;

        emit DomainUpdated(domainId, address(domains[domainId].validationLogic), domainParametersURI);
    }

    function get(uint256 domainId) external view returns (Domain memory) {
        return domains[domainId];
    }
}
