// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IComputeRegistry.sol";
import "./interfaces/IStakeManager.sol";
import "./interfaces/IDomainRegistry.sol";
import "./interfaces/IWorkValidation.sol";
import "./interfaces/IComputePool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract PrimeNetwork is AccessControlEnumerable {
    using MessageHashUtils for bytes32;

    bytes32 public constant FEDERATOR_ROLE = keccak256("FEDERATOR_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    IComputeRegistry public computeRegistry;
    IDomainRegistry public domainRegistry;
    IStakeManager public stakeManager;
    IComputePool public computePool;

    IERC20 public AIToken;

    constructor(address _federator, address _validator, IERC20 _AIToken) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FEDERATOR_ROLE, _federator);
        _grantRole(VALIDATOR_ROLE, _validator);
        AIToken = _AIToken;
    }

    function setModuleAddresses(
        address _computeRegistry,
        address _domainRegistry,
        address _stakeManager,
        address _computePool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        computeRegistry = IComputeRegistry(_computeRegistry);
        domainRegistry = IDomainRegistry(_domainRegistry);
        stakeManager = IStakeManager(_stakeManager);
        computePool = IComputePool(_computePool);
        computeRegistry.setComputePool(address(computePool));
    }

    function setFederator(address _federator) external onlyRole(FEDERATOR_ROLE) {
        grantRole(FEDERATOR_ROLE, _federator);
        revokeRole(FEDERATOR_ROLE, msg.sender);
    }

    function setValidator(address _validator) external onlyRole(FEDERATOR_ROLE) {
        grantRole(VALIDATOR_ROLE, _validator);
        revokeRole(VALIDATOR_ROLE, msg.sender);
    }

    function whitelistProvider(address provider) external {
        require(
            hasRole(VALIDATOR_ROLE, msg.sender) || hasRole(FEDERATOR_ROLE, msg.sender),
            "Must have VALIDATOR_ROLE or FEDERATOR_ROLE"
        );
        computeRegistry.setWhitelistStatus(provider, true);
        emit ProviderWhitelisted(provider);
    }

    function blacklistProvider(address provider) external onlyRole(VALIDATOR_ROLE) {
        computeRegistry.setWhitelistStatus(provider, false);
        emit ProviderBlacklisted(provider);
    }

    function validateNode(address provider, address nodekey) external onlyRole(VALIDATOR_ROLE) {
        computeRegistry.setNodeValidationStatus(provider, nodekey, true);
        emit ComputeNodeValidated(provider, nodekey);
    }

    function invalidateNode(address provider, address nodekey) external onlyRole(VALIDATOR_ROLE) {
        computeRegistry.setNodeValidationStatus(provider, nodekey, false);
        emit ComputeNodeInvalidated(provider, nodekey);
    }

    function setStakeMinimum(uint256 amount) external onlyRole(FEDERATOR_ROLE) {
        stakeManager.setStakeMinimum(amount);
    }

    function createDomain(string calldata domainName, IWorkValidation validationLogic, string calldata domainURI)
        external
        onlyRole(FEDERATOR_ROLE)
        returns (uint256)
    {
        uint256 domainId = domainRegistry.create(domainName, computePool, validationLogic, domainURI);
        return domainId;
    }

    function registerProvider(uint256 stake) external {
        uint256 stakeMinimum = stakeManager.getStakeMinimum();
        require(stake >= stakeMinimum, "Stake amount is below minimum");
        address provider = msg.sender;
        bool success = computeRegistry.register(provider);
        require(success, "Provider registration failed");
        AIToken.transferFrom(msg.sender, address(this), stake);
        AIToken.approve(address(stakeManager), stake);
        stakeManager.stake(provider, stake);
        emit ProviderRegistered(provider, stake);
    }

    function registerProviderWithPermit(uint256 stake, uint256 deadline, bytes memory signature) external {
        uint256 stakeMinimum = stakeManager.getStakeMinimum();
        require(stake >= stakeMinimum, "Stake amount is below minimum");
        address provider = msg.sender;
        bool success = computeRegistry.register(provider);
        require(success, "Provider registration failed");
        (bytes32 r, bytes32 s, uint8 v) = abi.decode(signature, (bytes32, bytes32, uint8));
        IERC20Permit(address(AIToken)).permit(msg.sender, address(this), stake, deadline, v, r, s);
        AIToken.transferFrom(msg.sender, address(this), stake);
        AIToken.approve(address(stakeManager), stake);
        stakeManager.stake(provider, stake);
        emit ProviderRegistered(provider, stake);
    }

    function deregisterProvider(address provider) external {
        require(hasRole(VALIDATOR_ROLE, msg.sender) || msg.sender == provider, "Unauthorized");
        require(computeRegistry.getProviderActiveNodes(provider) == 0, "Provider has active nodes");
        computeRegistry.deregister(provider);
        uint256 stake = stakeManager.getStake(provider);
        stakeManager.unstake(provider, stake);
        emit ProviderDeregistered(provider);
    }

    function addComputeNode(address nodekey, string calldata specsURI, uint256 computeUnits, bytes memory signature)
        external
    {
        address provider = msg.sender;
        // check provider exists
        require(computeRegistry.checkProviderExists(provider), "Provider not registered");
        require(computeRegistry.getWhitelistStatus(provider), "Provider not whitelisted");
        require(_verifyNodekeySignature(provider, nodekey, signature), "Invalid signature");
        computeRegistry.addComputeNode(provider, nodekey, computeUnits, specsURI);
        emit ComputeNodeAdded(provider, nodekey, specsURI);
    }

    function removeComputeNode(address provider, address nodekey) external {
        require(hasRole(VALIDATOR_ROLE, msg.sender) || msg.sender == provider, "Unauthorized");
        computeRegistry.removeComputeNode(provider, nodekey);
        emit ComputeNodeRemoved(provider, nodekey);
    }

    function slash(address provider, uint256 amount, bytes calldata reason) external onlyRole(VALIDATOR_ROLE) {
        uint256 slashed = stakeManager.slash(provider, amount, reason);
        AIToken.transfer(msg.sender, slashed);
    }

    function invalidateWork(uint256 poolId, uint256 penalty, bytes calldata data) external onlyRole(VALIDATOR_ROLE) {
        (address provider, address node) = computePool.invalidateWork(poolId, data);
        try stakeManager.slash(provider, penalty, data) {
            if (stakeManager.getStake(provider) < stakeManager.getStakeMinimum()) {
                computeRegistry.setWhitelistStatus(provider, false);
                emit ProviderBlacklisted(provider);
            }
        } catch {
            // if slashing failed for whatever reason, blacklist provider to make sure they can't submit more work
            computeRegistry.setWhitelistStatus(provider, false);
            emit ProviderBlacklisted(provider);
        }
        // invalidate node to queue it for reverification
        computeRegistry.setNodeValidationStatus(provider, node, false);
        emit ComputeNodeInvalidated(provider, node);
    }

    function _verifyNodekeySignature(address provider, address nodekey, bytes memory signature)
        internal
        view
        returns (bool)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(provider, nodekey)).toEthSignedMessageHash();
        return SignatureChecker.isValidSignatureNow(nodekey, messageHash, signature);
    }
}
