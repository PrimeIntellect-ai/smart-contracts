// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IComputeRegistry.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ComputeRegistry is IComputeRegistry, AccessControlEnumerable {
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE");
    bytes32 public constant COMPUTE_POOL_ROLE = keccak256("COMPUTE_POOL_ROLE");

    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => ComputeProvider) public providers;
    mapping(address => address) public nodeProviderMap;
    EnumerableMap.AddressToUintMap private nodeSubkeyToIndex;
    EnumerableSet.AddressSet private providerSet;
    mapping(address => EnumerableSet.AddressSet) private providerValidatedNodes;
    mapping(address => uint256) public providerTotalCompute;

    constructor(address primeAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, primeAdmin);
        _grantRole(PRIME_ROLE, primeAdmin);
    }

    function _fetchNodeOrZero(address provider, address subkey) internal view returns (ComputeNode memory) {
        ComputeNode memory n = providers[provider].nodes[nodeSubkeyToIndex.get(subkey)];
        if (n.subkey != subkey) {
            return ComputeNode(address(0), address(0), "", 0, 0, false, false);
        } else {
            return n;
        }
    }

    function _nodeExists(address provider, address subkey) internal view returns (bool) {
        return providers[provider].nodes[nodeSubkeyToIndex.get(subkey)].subkey == subkey;
    }

    function setComputePool(address computePool) external onlyRole(PRIME_ROLE) {
        _grantRole(COMPUTE_POOL_ROLE, computePool);
    }

    function register(address provider) external onlyRole(PRIME_ROLE) returns (bool) {
        ComputeProvider storage cp = providers[provider];
        if (cp.providerAddress == address(0)) {
            cp.providerAddress = provider;
            cp.isWhitelisted = false;
            cp.activeNodes = 0;
            cp.nodes = new ComputeNode[](0);
            providerSet.add(provider);
            return true;
        }
        return false;
    }

    function deregister(address provider) external onlyRole(PRIME_ROLE) returns (bool) {
        if (providers[provider].providerAddress == address(0)) {
            return false;
        } else {
            delete providers[provider];
            providerSet.remove(provider);
            return true;
        }
    }

    function addComputeNode(address provider, address subkey, uint256 computeUnits, string calldata specsURI)
        external
        onlyRole(PRIME_ROLE)
        returns (uint256)
    {
        address existingProvider = nodeProviderMap[subkey];
        if (existingProvider != address(0)) {
            require(existingProvider == provider, "ComputeRegistry: node has already registered with another provider");
            // check if this node already exists in this providers list
            (bool exists, uint256 nodeIndex) = nodeSubkeyToIndex.tryGet(subkey);
            if (exists && nodeIndex < providers[provider].nodes.length) {
                // check if the node is already registered with this provider
                ComputeNode memory existingNode = providers[provider].nodes[nodeIndex];
                require(existingNode.subkey != subkey, "ComputeRegistry: node already exists with this provider");
            }
            // else node existed in the past, got removed, and is just being readded, continue on as normal
        }
        ComputeProvider storage cp = providers[provider];
        ComputeNode memory cn;
        cn.provider = provider;
        cn.computeUnits = uint32(computeUnits);
        cn.specsURI = specsURI;
        cn.benchmarkScore = 0;
        cn.isActive = false;
        cn.subkey = subkey;
        cp.nodes.push(cn);
        uint256 index = cp.nodes.length - 1;
        nodeSubkeyToIndex.set(subkey, index);
        nodeProviderMap[subkey] = provider;
        providerTotalCompute[provider] += uint256(computeUnits);
        return index;
    }

    function removeComputeNode(address provider, address subkey) external onlyRole(PRIME_ROLE) returns (bool) {
        require(_nodeExists(provider, subkey), "ComputeRegistry: node not found");
        ComputeProvider storage cp = providers[provider];
        uint256 index = nodeSubkeyToIndex.get(subkey);
        ComputeNode memory cn = cp.nodes[index];
        // should throw if subkey doesn't exist, but we'll check anyway
        if (cn.subkey != subkey) {
            return false;
        }
        require(cn.isActive == false, "ComputeRegistry: node must be inactive to remove");
        // swap node we're removing with last node
        cp.nodes[index] = cp.nodes[cp.nodes.length - 1];
        // update index of the node we swapped
        nodeSubkeyToIndex.set(cp.nodes[index].subkey, index);
        // remove last node
        cp.nodes.pop();
        nodeSubkeyToIndex.remove(subkey);
        providerTotalCompute[provider] -= uint256(cn.computeUnits);
        return true;
    }

    function updateNodeURI(address provider, address subkey, string calldata specsURI) external onlyRole(PRIME_ROLE) {
        require(_nodeExists(provider, subkey), "ComputeRegistry: node not found");
        ComputeNode storage cn = providers[provider].nodes[nodeSubkeyToIndex.get(subkey)];
        cn.specsURI = specsURI;
    }

    function updateNodeStatus(address provider, address subkey, bool isActive) external onlyRole(COMPUTE_POOL_ROLE) {
        require(_nodeExists(provider, subkey), "ComputeRegistry: node not found");
        ComputeNode storage cn = providers[provider].nodes[nodeSubkeyToIndex.get(subkey)];
        cn.isActive = isActive;
        if (isActive) {
            providers[provider].activeNodes++;
        } else {
            providers[provider].activeNodes--;
        }
    }

    function updateNodeBenchmark(address provider, address subkey, uint256 benchmarkScore)
        external
        onlyRole(PRIME_ROLE)
    {
        require(_nodeExists(provider, subkey), "ComputeRegistry: node not found");
        ComputeNode storage cn = providers[provider].nodes[nodeSubkeyToIndex.get(subkey)];
        cn.benchmarkScore = uint32(benchmarkScore);
    }

    function setWhitelistStatus(address provider, bool status) external onlyRole(PRIME_ROLE) {
        providers[provider].isWhitelisted = status;
    }

    function setNodeValidationStatus(address provider, address subkey, bool status) external onlyRole(PRIME_ROLE) {
        require(_nodeExists(provider, subkey), "ComputeRegistry: node not found");
        bool current_status = providers[provider].nodes[nodeSubkeyToIndex.get(subkey)].isValidated;
        if (current_status == status) {
            return;
        }
        if (status) {
            providerValidatedNodes[provider].add(subkey);
        } else {
            providerValidatedNodes[provider].remove(subkey);
        }
        providers[provider].nodes[nodeSubkeyToIndex.get(subkey)].isValidated = status;
    }

    // view functions

    function getWhitelistStatus(address provider) external view returns (bool) {
        return providers[provider].isWhitelisted;
    }

    function getNodeValidationStatus(address provider, address subkey) external view returns (bool) {
        return _fetchNodeOrZero(provider, subkey).isValidated;
    }

    function getProvider(address provider) external view returns (ComputeProvider memory) {
        return providers[provider];
    }

    function getProviderActiveNodes(address provider) external view returns (uint32) {
        return providers[provider].activeNodes;
    }

    function getProviderTotalNodes(address provider) external view returns (uint32) {
        return uint32(providers[provider].nodes.length);
    }

    function getNodes(address provider, uint256 page, uint256 limit) external view returns (ComputeNode[] memory) {
        if (page == 0 && limit == 0) {
            return providers[provider].nodes;
        } else {
            uint256 start = (page - 1) * limit;
            uint256 end = start + limit;
            if (end > providers[provider].nodes.length) {
                end = providers[provider].nodes.length;
            }
            ComputeNode[] memory result = new ComputeNode[](end - start);
            for (uint256 i = start; i < end; i++) {
                result[i - start] = providers[provider].nodes[i];
            }
            return result;
        }
    }

    function getNode(address provider, address subkey) external view returns (ComputeNode memory) {
        return _fetchNodeOrZero(provider, subkey);
    }

    function getNode(address subkey) external view returns (ComputeNode memory) {
        address provider = nodeProviderMap[subkey];
        return _fetchNodeOrZero(provider, subkey);
    }

    function getProviderValidatedNodes(address provider, bool filterForActive)
        external
        view
        returns (address[] memory)
    {
        address[] memory validatedNodes = providerValidatedNodes[provider].values();
        if (!filterForActive) {
            return validatedNodes;
        } else {
            address[] memory result = new address[](providers[provider].activeNodes);
            uint32 activeCount = 0;
            for (uint256 i = 0; i < validatedNodes.length; i++) {
                if (providers[provider].nodes[nodeSubkeyToIndex.get(validatedNodes[i])].isActive) {
                    result[activeCount] = validatedNodes[i];
                    activeCount++;
                }
            }
            return result;
        }
    }

    function getNodeComputeUnits(address subkey) external view returns (uint256) {
        address provider = nodeProviderMap[subkey];
        return _fetchNodeOrZero(provider, subkey).computeUnits;
    }

    function getNodeProvider(address subkey) external view returns (address) {
        return nodeProviderMap[subkey];
    }

    function getNodeContractData(address subkey) external view returns (address, uint32, bool, bool) {
        // optimize by not pulling out entire node struct
        address provider = nodeProviderMap[subkey];
        if (provider != address(0)) {
            ComputeNode storage node = providers[provider].nodes[nodeSubkeyToIndex.get(subkey)];
            if (node.subkey == subkey) {
                return (node.provider, node.computeUnits, node.isActive, node.isValidated);
            }
        }
        return (address(0), 0, false, false);
    }

    function getProviderAddressList() external view returns (address[] memory) {
        return providerSet.values();
    }

    function checkProviderExists(address provider) external view returns (bool) {
        return providerSet.contains(provider);
    }

    function getProviderTotalCompute(address provider) external view returns (uint256) {
        return providerTotalCompute[provider];
    }
}
