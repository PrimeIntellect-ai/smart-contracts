// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IComputeRegistry.sol";
import "./interfaces/IStakeManager.sol";
import "./interfaces/IDomainRegistry.sol";
import "./interfaces/IWorkValidation.sol";
import "./interfaces/IJobManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PrimeNetwork is AccessControl {
    bytes32 public constant FEDERATOR_ROLE = keccak256("FEDERATOR_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    IComputeRegistry public computeRegistry;
    IDomainRegistry public domainRegistry;
    IStakeManager public stakeManager;
    IJobManager public jobManager;

    IERC20 public PrimeToken;

    constructor(
        address _federator,
        address _validator,
        IERC20 _PrimeToken,
        IComputeRegistry _computeRegistry,
        IDomainRegistry _domainRegistry,
        IStakeManager _stakeManager,
        IJobManager _jobManager
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FEDERATOR_ROLE, _federator);
        _grantRole(VALIDATOR_ROLE, _validator);
        PrimeToken = _PrimeToken;
        computeRegistry = _computeRegistry;
        domainRegistry = _domainRegistry;
        stakeManager = _stakeManager;
        jobManager = _jobManager;
    }

    function setFederator(address _federator) external onlyRole(FEDERATOR_ROLE) {
        grantRole(FEDERATOR_ROLE, _federator);
        revokeRole(FEDERATOR_ROLE, msg.sender);
    }

    function setValidator(address _validator) external onlyRole(FEDERATOR_ROLE) {
        grantRole(VALIDATOR_ROLE, _validator);
        revokeRole(VALIDATOR_ROLE, msg.sender);
    }

    function whitelistProvider(address provider) external onlyRole(FEDERATOR_ROLE) {
        computeRegistry.setWhitelistStatus(provider, true);
        emit ProviderWhitelisted(provider);
    }

    function blacklistProvider(address provider) external onlyRole(FEDERATOR_ROLE) {
        computeRegistry.setWhitelistStatus(provider, false);
        emit ProviderBlacklisted(provider);
    }

    function setStakeMinimum(uint256 amount) external onlyRole(FEDERATOR_ROLE) {
        stakeManager.setStakeMinimum(amount);
        emit StakeMinimumUpdate(amount);
    }

    function createDomain(string calldata domainName, IWorkValidation validationLogic, string calldata domainURI)
        external
        onlyRole(FEDERATOR_ROLE)
    {
        uint256 domainId = domainRegistry.create(domainName, jobManager, validationLogic, domainURI);
        require(domainId > 0, "Domain creation failed");
        emit DomainCreated(domainName, domainId);
    }

    function registerProvider(uint256 stake) external {
        uint256 stakeMinimum = stakeManager.getStakeMinimum();
        require(stake >= stakeMinimum, "Stake amount is below minimum");
        address provider = msg.sender;
        bool success = computeRegistry.register(provider);
        require(success, "Provider registration failed");
        PrimeToken.transferFrom(msg.sender, address(this), stake);
        PrimeToken.approve(address(stakeManager), stake);
        stakeManager.stake(provider, stake);
        emit ProviderRegistered(provider, stake);
    }

    function deregisterProvider(address provider) external {
        require(hasRole(FEDERATOR_ROLE, msg.sender) || msg.sender == provider, "Unauthorized");
        computeRegistry.deregister(provider);
        uint256 stake = stakeManager.getStake(provider);
        stakeManager.unstake(provider, stake);
        emit ProviderDeregistered(provider);
    }

    function addComputeNode(address nodekey, string calldata specsURI) external {
        address provider = msg.sender;
        computeRegistry.addComputeNode(provider, nodekey, specsURI);
        emit ComputeNodeAdded(provider, nodekey, specsURI);
    }

    function removeComputeNode(address provider, address nodekey) external {
        require(hasRole(FEDERATOR_ROLE, msg.sender) || msg.sender == provider, "Unauthorized");
        computeRegistry.removeComputeNode(provider, nodekey);
        emit ComputeNodeRemoved(provider, nodekey);
    }
}
