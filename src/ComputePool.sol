// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IComputePool.sol";
import "./interfaces/IDomainRegistry.sol";
import "./interfaces/IRewardsDistributor.sol";
import "./interfaces/IRewardsDistributorFactory.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ComputePool is IComputePool, AccessControlEnumerable {
    using MessageHashUtils for bytes32;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct PoolState {
        mapping(address => uint256) providerActiveNodes;
        EnumerableSet.AddressSet poolProviders;
        EnumerableSet.AddressSet poolNodes;
        mapping(address => bool) blacklistedProviders;
        mapping(address => bool) blacklistedNodes;
        IRewardsDistributor rewardsDistributor;
    }

    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE");
    bytes32 public constant FEDERATOR_ROLE = keccak256("FEDERATOR_ROLE");

    mapping(uint256 => PoolInfo) public pools;
    uint256 public poolIdCounter;
    IComputeRegistry public computeRegistry;
    IDomainRegistry public domainRegistry;
    IRewardsDistributorFactory public rewardsDistributorFactory;
    IERC20 public AIToken;

    mapping(uint256 => PoolState) private poolStates;
    mapping(bytes32 => bool) private usedMessageHashes;

    modifier onlyExistingPool(uint256 poolId) {
        // check creator here since it's the only field that can't be 0
        require(pools[poolId].creator != address(0), "ComputePool: pool does not exist");
        _;
    }

    modifier onlyPoolCreatorOrManager(uint256 poolId) {
        require(
            pools[poolId].creator == msg.sender || pools[poolId].computeManagerKey == msg.sender,
            "ComputePool: only creator or manager can perform this action"
        );
        _;
    }

    modifier onlyValidProvider(uint256 poolId, address provider) {
        require(pools[poolId].status == PoolStatus.ACTIVE, "ComputePool: pool is not active");
        require(!poolStates[poolId].blacklistedProviders[provider], "ComputePool: provider is blacklisted");
        require(
            computeRegistry.getWhitelistStatus(provider),
            "ComputePool: provider has not been allowed to join pools by federator"
        );
        _;
    }

    constructor(
        address _primeAdmin,
        IDomainRegistry _domainRegistry,
        IComputeRegistry _computeRegistry,
        IRewardsDistributorFactory _rewardsDistributorFactory,
        IERC20 _AIToken
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _primeAdmin);
        _grantRole(PRIME_ROLE, _primeAdmin);
        poolIdCounter = 0;
        AIToken = _AIToken;
        computeRegistry = _computeRegistry;
        domainRegistry = _domainRegistry;
        rewardsDistributorFactory = _rewardsDistributorFactory;
        address federator = IAccessControlEnumerable(address(_primeAdmin)).getRoleMember(FEDERATOR_ROLE, 0);
        _grantRole(FEDERATOR_ROLE, federator);
    }

    function _verifyPoolInvite(
        uint256 domainId,
        uint256 poolId,
        address computeManagerKey,
        address nodekey,
        uint256 nonce,
        uint256 expiration,
        bytes memory signature
    ) internal returns (bool) {
        require(expiration > block.timestamp, "ComputePool: invite expired");
        bytes32 messageHash =
            keccak256(abi.encodePacked(domainId, poolId, nodekey, nonce, expiration)).toEthSignedMessageHash();
        require(!usedMessageHashes[messageHash], "ComputePool: invite already used");
        bool valid = SignatureChecker.isValidSignatureNow(computeManagerKey, messageHash, signature);
        if (valid) {
            usedMessageHashes[messageHash] = true;
        }
        return valid;
    }

    function _removeNodeSafe(uint256 poolId, address provider, address node) internal {
        (address node_provider, uint32 computeUnits,,) = computeRegistry.getNodeContractData(node);
        require(poolStates[poolId].poolNodes.contains(node), "ComputePool: node not in pool");
        if (node_provider == provider) {
            _removeNode(poolId, provider, node, computeUnits);
            emit ComputePoolLeft(poolId, provider, node);
        }
    }

    function _removeNode(uint256 poolId, address provider, address nodekey, uint32 computeUnits) internal {
        // WARNING: order here is VERY important, computeUnits must be removed AFTER leavePool
        poolStates[poolId].poolNodes.remove(nodekey);
        poolStates[poolId].rewardsDistributor.leavePool(nodekey);
        pools[poolId].totalCompute -= computeUnits;
        poolStates[poolId].providerActiveNodes[provider]--;
        computeRegistry.updateNodeStatus(provider, nodekey, false);
    }

    function _addNode(uint256 poolId, address provider, address nodekey, uint32 computeUnits) internal {
        // WARNING: order here is VERY important, computeUnits must be added AFTER joinPool
        poolStates[poolId].poolNodes.add(nodekey);
        poolStates[poolId].rewardsDistributor.joinPool(nodekey);
        pools[poolId].totalCompute += computeUnits;
        poolStates[poolId].providerActiveNodes[provider]++;
        computeRegistry.updateNodeStatus(provider, nodekey, true);
    }

    function createComputePool(
        uint256 domainId,
        address computeManagerKey,
        string calldata poolName,
        string calldata poolDataURI,
        uint256 computeLimit
    ) external onlyRole(FEDERATOR_ROLE) returns (uint256) {
        require(domainRegistry.get(domainId).domainId == domainId, "ComputePool: domain does not exist");

        pools[poolIdCounter] = PoolInfo({
            poolId: poolIdCounter,
            domainId: domainId,
            poolName: poolName,
            creator: msg.sender,
            computeManagerKey: computeManagerKey,
            creationTime: block.timestamp,
            startTime: 0,
            endTime: 0,
            poolDataURI: poolDataURI,
            poolValidationLogic: address(0),
            totalCompute: 0,
            computeLimit: computeLimit,
            status: PoolStatus.PENDING
        });

        poolStates[poolIdCounter].rewardsDistributor =
            rewardsDistributorFactory.createRewardsDistributor(computeRegistry, poolIdCounter);

        poolIdCounter++;

        emit ComputePoolCreated(poolIdCounter - 1, domainId, msg.sender);

        return poolIdCounter - 1;
    }

    function startComputePool(uint256 poolId) external onlyExistingPool(poolId) onlyPoolCreatorOrManager(poolId) {
        require(pools[poolId].status == PoolStatus.PENDING, "ComputePool: pool is not pending");

        pools[poolId].startTime = block.timestamp;
        pools[poolId].status = PoolStatus.ACTIVE;

        emit ComputePoolStarted(poolId, block.timestamp);
    }

    function endComputePool(uint256 poolId) external onlyExistingPool(poolId) onlyPoolCreatorOrManager(poolId) {
        require(pools[poolId].status == PoolStatus.ACTIVE, "ComputePool: pool is not active");

        pools[poolId].endTime = block.timestamp;
        pools[poolId].status = PoolStatus.COMPLETED;

        poolStates[poolId].rewardsDistributor.endRewards();

        emit ComputePoolEnded(poolId);
    }

    function _joinComputePool(
        uint256 poolId,
        address provider,
        address[] memory nodekey,
        uint256[] memory nonces,
        uint256[] memory expirations,
        bytes[] memory signatures
    ) internal {
        for (uint256 i = 0; i < nodekey.length; i++) {
            require(!poolStates[poolId].blacklistedNodes[nodekey[i]], "ComputePool: node is blacklisted");
        }

        require(
            computeRegistry.getWhitelistStatus(provider),
            "ComputePool: provider has not been allowed to join pools by federator"
        );

        if (!poolStates[poolId].poolProviders.contains(provider)) {
            poolStates[poolId].poolProviders.add(provider);
        }
        for (uint256 i = 0; i < nodekey.length; i++) {
            (address node_provider, uint32 computeUnits, bool isActive, bool isValidated) =
                computeRegistry.getNodeContractData(nodekey[i]);
            require(node_provider == provider, "ComputePool: node does not exist or not owned by provider");
            require(isActive == false, "ComputePool: node can only be in one pool at a time");
            require(isValidated, "ComputePool: node is not validated");
            require(
                _verifyPoolInvite(
                    pools[poolId].domainId,
                    poolId,
                    pools[poolId].computeManagerKey,
                    nodekey[i],
                    nonces[i],
                    expirations[i],
                    signatures[i]
                ),
                "ComputePool: invalid invite"
            );
            uint256 addedCompute = pools[poolId].totalCompute + computeUnits;
            if (pools[poolId].computeLimit > 0) {
                require(addedCompute <= pools[poolId].computeLimit, "ComputePool: pool is at capacity");
            }
            _addNode(poolId, provider, nodekey[i], computeUnits);
        }
    }

    function joinComputePool(
        uint256 poolId,
        address provider,
        address nodekey,
        uint256 nonce,
        uint256 expiration,
        bytes memory signature
    ) external onlyExistingPool(poolId) onlyValidProvider(poolId, provider) {
        require(msg.sender == provider, "ComputePool: only provider can join pool");

        address[] memory nodekeys = new address[](1);
        bytes[] memory signatures = new bytes[](1);
        uint256[] memory nonces = new uint256[](1);
        uint256[] memory expirations = new uint256[](1);
        nodekeys[0] = nodekey;
        nonces[0] = nonce;
        expirations[0] = expiration;
        signatures[0] = signature;

        _joinComputePool(poolId, provider, nodekeys, nonces, expirations, signatures);

        emit ComputePoolJoined(poolId, provider, nodekeys);
    }

    function joinComputePool(
        uint256 poolId,
        address provider,
        address[] memory nodekey,
        uint256[] memory nonces,
        uint256[] memory expirations,
        bytes[] memory signatures
    ) external onlyExistingPool(poolId) onlyValidProvider(poolId, provider) {
        require(msg.sender == provider, "ComputePool: only provider can join pool");

        _joinComputePool(poolId, provider, nodekey, nonces, expirations, signatures);

        emit ComputePoolJoined(poolId, provider, nodekey);
    }

    function _leaveComputePool(uint256 poolId, address provider, address[] memory nodekeys) internal {
        if (nodekeys.length == 0) {
            // Remove all nodes belonging to that provider
            address[] memory nodes = poolStates[poolId].poolNodes.values();
            for (uint256 i = 0; i < nodes.length; ++i) {
                _removeNodeSafe(poolId, provider, nodes[i]);
            }
        } else {
            // Just remove the listed nodes
            for (uint256 i = 0; i < nodekeys.length; i++) {
                _removeNodeSafe(poolId, provider, nodekeys[i]);
            }
        }
        if (poolStates[poolId].providerActiveNodes[provider] == 0) {
            poolStates[poolId].poolProviders.remove(provider);
        }
    }

    function leaveComputePool(uint256 poolId, address provider, address nodekey) external onlyExistingPool(poolId) {
        require(msg.sender == provider, "ComputePool: only provider can leave pool");

        if (nodekey == address(0)) {
            address[] memory nodekeys = new address[](0);
            _leaveComputePool(poolId, provider, nodekeys);
        } else {
            address[] memory nodekeys = new address[](1);
            nodekeys[0] = nodekey;
            _leaveComputePool(poolId, provider, nodekeys);
        }
    }

    function leaveComputePool(uint256 poolId, address provider, address[] memory nodekeys)
        external
        onlyExistingPool(poolId)
    {
        require(msg.sender == provider, "ComputePool: only provider can leave pool");

        _leaveComputePool(poolId, provider, nodekeys);
    }

    function changeComputePool(
        uint256 fromPoolId,
        uint256 toPoolId,
        address[] memory nodekeys,
        uint256[] memory nonces,
        uint256[] memory expirations,
        bytes[] memory signatures
    ) external onlyExistingPool(fromPoolId) onlyExistingPool(toPoolId) {
        require(pools[toPoolId].status == PoolStatus.ACTIVE, "ComputePool: dest pool is not ready");
        address provider = msg.sender;

        require(!poolStates[toPoolId].blacklistedProviders[provider], "ComputePool: provider is blacklisted");

        if (nodekeys.length == poolStates[fromPoolId].providerActiveNodes[provider]) {
            // If all nodes are being moved, just move the provider
            _leaveComputePool(fromPoolId, provider, new address[](0));
        } else {
            _leaveComputePool(fromPoolId, provider, nodekeys);
        }
        _joinComputePool(toPoolId, provider, nodekeys, nonces, expirations, signatures);
    }

    function submitWork(uint256 poolId, address node, bytes calldata data) external onlyExistingPool(poolId) {
        address provider = msg.sender;

        require(poolStates[poolId].poolNodes.contains(node), "ComputePool: node not in pool");
        require(computeRegistry.getNodeProvider(node) == provider, "ComputePool: node not owned by provider");
        require(pools[poolId].status == PoolStatus.ACTIVE, "ComputePool: dest pool is not ready");
        require(!poolStates[poolId].blacklistedNodes[node], "ComputePool: node is blacklisted");
        require(!poolStates[poolId].blacklistedProviders[provider], "ComputePool: provider is blacklisted");
        require(
            computeRegistry.getWhitelistStatus(provider),
            "ComputePool: provider has not been allowed to join pools by federator"
        );

        IDomainRegistry.Domain memory domainInfo = domainRegistry.get(pools[poolId].domainId);
        IWorkValidation workValidation = IWorkValidation(domainInfo.validationLogic);
        (bool success, uint256 workUnits) =
            workValidation.submitWork(pools[poolId].domainId, poolId, provider, node, data);

        if (success) {
            IRewardsDistributor rewardsDistributor = poolStates[poolId].rewardsDistributor;
            rewardsDistributor.submitWork(node, workUnits);
        }
    }

    function invalidateWork(uint256 poolId, bytes calldata data)
        external
        onlyExistingPool(poolId)
        onlyRole(PRIME_ROLE)
        returns (address, address)
    {
        IDomainRegistry.Domain memory domainInfo = domainRegistry.get(pools[poolId].domainId);
        IWorkValidation workValidation = IWorkValidation(domainInfo.validationLogic);
        (address provider, address node) = workValidation.invalidateWork(poolId, data);
        IRewardsDistributor rewardsDistributor = poolStates[poolId].rewardsDistributor;
        rewardsDistributor.slashPendingRewards(node);
        if (poolStates[poolId].poolNodes.contains(node)) {
            _ejectNode(poolId, node);
        }
        return (provider, node);
    }

    function softInvalidateWork(uint256 poolId, bytes calldata data)
        external
        onlyExistingPool(poolId)
        onlyRole(PRIME_ROLE)
        returns (address, address, uint256)
    {
        IDomainRegistry.Domain memory domainInfo = domainRegistry.get(pools[poolId].domainId);
        IWorkValidation workValidation = IWorkValidation(domainInfo.validationLogic);
        (address provider, address node, uint256 workUnits) = workValidation.softInvalidateWork(poolId, data);
        IRewardsDistributor rewardsDistributor = poolStates[poolId].rewardsDistributor;
        rewardsDistributor.removeWork(node, workUnits);
        // Note: we don't eject the node with soft invalidation
        return (provider, node, workUnits);
    }

    //
    // Management functions
    //
    function updateComputePoolURI(uint256 poolId, string calldata poolDataURI)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        pools[poolId].poolDataURI = poolDataURI;

        emit ComputePoolURIUpdated(poolId, poolDataURI);
    }

    function updateComputeLimit(uint256 poolId, uint256 computeLimit)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        pools[poolId].computeLimit = computeLimit;

        emit ComputePoolLimitUpdated(poolId, computeLimit);
    }

    function _ejectNode(uint256 poolId, address nodekey) internal {
        (address node_provider, uint32 computeUnits,,) = computeRegistry.getNodeContractData(nodekey);
        _removeNode(poolId, node_provider, nodekey, computeUnits);

        if (poolStates[poolId].providerActiveNodes[node_provider] == 0) {
            poolStates[poolId].poolProviders.remove(node_provider);
        }

        emit ComputePoolNodeEjected(poolId, node_provider, nodekey);
    }

    function ejectNode(uint256 poolId, address nodekey)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        require(poolStates[poolId].poolNodes.contains(nodekey), "ComputePool: node not in pool");
        _ejectNode(poolId, nodekey);
    }

    function _blacklistProvider(uint256 poolId, address provider) internal {
        // Add to blacklist set
        poolStates[poolId].blacklistedProviders[provider] = true;
        emit ComputePoolProviderBlacklisted(poolId, provider);
    }

    function blacklistProvider(uint256 poolId, address provider)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        require(provider != address(0), "ComputePool: provider cannot be zero address");

        _blacklistProvider(poolId, provider);
    }

    function blacklistProviderList(uint256 poolId, address[] memory providers)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] != address(0)) {
                _blacklistProvider(poolId, providers[i]);
            }
        }
    }

    function _purgeProvider(uint256 poolId, address provider) internal {
        address[] memory provider_nodes = computeRegistry.getProviderValidatedNodes(provider, true);
        for (uint256 i = 0; i < provider_nodes.length; i++) {
            if (poolStates[poolId].poolNodes.contains(provider_nodes[i])) {
                (address node_provider, uint32 computeUnits,,) = computeRegistry.getNodeContractData(provider_nodes[i]);
                if (node_provider == provider) {
                    _removeNode(poolId, provider, provider_nodes[i], computeUnits);
                }
            }
        }

        emit ComputePoolPurgedProvider(poolId, provider);

        // Remove from active set
        poolStates[poolId].poolProviders.remove(provider);
    }

    function purgeProvider(uint256 poolId, address provider)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        require(provider != address(0), "ComputePool: provider cannot be zero address");

        _purgeProvider(poolId, provider);
    }

    function blacklistAndPurgeProvider(uint256 poolId, address provider)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        require(provider != address(0), "ComputePool: provider cannot be zero address");

        _blacklistProvider(poolId, provider);
        _purgeProvider(poolId, provider);
    }

    function _blacklistNode(uint256 poolId, address nodekey) internal {
        address node_provider = address(0);
        if (poolStates[poolId].poolNodes.contains(nodekey)) {
            uint32 computeUnits = 0;
            (node_provider, computeUnits,,) = computeRegistry.getNodeContractData(nodekey);
            if (node_provider != address(0)) {
                _removeNode(poolId, node_provider, nodekey, computeUnits);
                if (poolStates[poolId].providerActiveNodes[node_provider] == 0) {
                    poolStates[poolId].poolProviders.remove(node_provider);
                }
            }
        }
        poolStates[poolId].blacklistedNodes[nodekey] = true;
        emit ComputePoolNodeBlacklisted(poolId, node_provider, nodekey);
    }

    function blacklistNode(uint256 poolId, address nodekey)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        _blacklistNode(poolId, nodekey);
    }

    function blacklistNodeList(uint256 poolId, address[] memory nodekeys)
        external
        onlyExistingPool(poolId)
        onlyPoolCreatorOrManager(poolId)
    {
        for (uint256 i = 0; i < nodekeys.length; i++) {
            _blacklistNode(poolId, nodekeys[i]);
        }
    }

    //
    // View functions
    //
    function getComputePool(uint256 poolId) external view returns (PoolInfo memory) {
        return pools[poolId];
    }

    function getComputePoolProviders(uint256 poolId) external view returns (address[] memory) {
        return poolStates[poolId].poolProviders.values();
    }

    function getComputePoolNodes(uint256 poolId) external view returns (address[] memory) {
        return poolStates[poolId].poolNodes.values();
    }

    function getProviderActiveNodesInPool(uint256 poolId, address provider) external view returns (uint256) {
        return poolStates[poolId].providerActiveNodes[provider];
    }

    function getRewardToken() external view returns (address) {
        return address(AIToken);
    }

    function getRewardDistributorForPool(uint256 poolId) external view returns (IRewardsDistributor) {
        return poolStates[poolId].rewardsDistributor;
    }

    function getComputePoolTotalCompute(uint256 poolId) external view returns (uint256) {
        return pools[poolId].totalCompute;
    }

    function isProviderBlacklistedFromPool(uint256 poolId, address provider) external view returns (bool) {
        return poolStates[poolId].blacklistedProviders[provider];
    }

    function isNodeBlacklistedFromPool(uint256 poolId, address nodekey) external view returns (bool) {
        return poolStates[poolId].blacklistedNodes[nodekey];
    }

    function isNodeInPool(uint256 poolId, address nodekey) external view returns (bool) {
        return poolStates[poolId].poolNodes.contains(nodekey);
    }

    function isProviderInPool(uint256 poolId, address provider) external view returns (bool) {
        return poolStates[poolId].poolProviders.contains(provider);
    }
}
