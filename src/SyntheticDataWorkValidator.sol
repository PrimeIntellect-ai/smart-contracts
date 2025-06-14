// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IWorkValidation.sol";

event WorkSubmitted(uint256 poolId, address provider, address nodeId, bytes32 workKey, uint256 workUnits);

event WorkInvalidated(uint256 poolId, address provider, address nodeId, bytes32 workKey, uint256 workUnits);

event WorkRemoved(uint256 poolId, address provider, address nodeId, bytes32 workKey, uint256 workUnits);

contract SyntheticDataWorkValidator is IWorkValidation {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint256 domainId;
    address computePool;
    uint256 workValidityPeriod = 1 days;

    struct WorkState {
        EnumerableSet.Bytes32Set workKeys;
        EnumerableSet.Bytes32Set invalidWorkKeys;
        mapping(bytes32 => WorkInfo) work;
    }

    struct WorkInfo {
        address provider;
        address nodeId;
        uint64 timestamp;
        uint256 workUnits;
    }

    mapping(uint256 => WorkState) poolWork;

    constructor(uint256 _domainId, address _computePool, uint256 _workValidityPeriod) {
        domainId = _domainId;
        computePool = _computePool;
        workValidityPeriod = _workValidityPeriod;
    }

    function submitWork(uint256 _domainId, uint256 poolId, address provider, address nodeId, bytes calldata data)
        external
        returns (bool, uint256)
    {
        require(msg.sender == computePool, "Unauthorized");
        require(data.length >= 64, "Data too short");
        require(domainId == _domainId, "Invalid domainId");
        bytes32 workKey;
        uint256 workUnits = 0;
        assembly {
            workKey := calldataload(data.offset)
            workUnits := calldataload(add(data.offset, 32))
        }
        require(!poolWork[poolId].workKeys.contains(workKey), "Work already submitted");
        require(!poolWork[poolId].invalidWorkKeys.contains(workKey), "Work already invalidated");
        require(workUnits > 0, "Invalid work units");

        poolWork[poolId].workKeys.add(workKey);
        poolWork[poolId].work[workKey] = WorkInfo(provider, nodeId, uint64(block.timestamp), workUnits);

        emit WorkSubmitted(poolId, provider, nodeId, workKey, workUnits);

        return (true, workUnits);
    }

    function invalidateWork(uint256 poolId, bytes calldata data) external returns (address, address) {
        require(msg.sender == computePool, "Unauthorized");
        require(data.length >= 32, "Data too short");
        bytes32 workKey;
        assembly {
            workKey := calldataload(data.offset)
        }
        require(poolWork[poolId].workKeys.contains(workKey), "Work not found");
        require(!poolWork[poolId].invalidWorkKeys.contains(workKey), "Work already invalidated");
        require(
            block.timestamp - poolWork[poolId].work[workKey].timestamp < workValidityPeriod,
            "Work invalidation window has lapsed"
        );

        poolWork[poolId].invalidWorkKeys.add(workKey);
        WorkInfo memory info = poolWork[poolId].work[workKey];
        poolWork[poolId].workKeys.remove(workKey);

        emit WorkInvalidated(poolId, info.provider, info.nodeId, workKey, info.workUnits);

        return (info.provider, info.nodeId);
    }

    function softInvalidateWork(uint256 poolId, bytes calldata data) external returns (address, address, uint256) {
        require(msg.sender == computePool, "Unauthorized");
        require(data.length >= 64, "Data too short for soft invalidation");

        // Decode both workKey and workUnits for soft invalidation
        bytes32 workKey;
        uint256 workUnits;
        assembly {
            workKey := calldataload(data.offset)
            workUnits := calldataload(add(data.offset, 32))
        }

        require(poolWork[poolId].workKeys.contains(workKey), "Work not found");
        require(!poolWork[poolId].invalidWorkKeys.contains(workKey), "Work already invalidated");
        require(
            block.timestamp - poolWork[poolId].work[workKey].timestamp < workValidityPeriod,
            "Work invalidation window has lapsed"
        );

        WorkInfo memory info = poolWork[poolId].work[workKey];

        // Move work from valid to invalid (same as hard invalidation)
        poolWork[poolId].invalidWorkKeys.add(workKey);
        poolWork[poolId].workKeys.remove(workKey);

        emit WorkRemoved(poolId, info.provider, info.nodeId, workKey, workUnits);

        // Return the specified work units to be soft-removed (key difference)
        return (info.provider, info.nodeId, workUnits);
    }

    function getWorkInfo(uint256 poolId, bytes32 workKey) external view returns (WorkInfo memory) {
        return poolWork[poolId].work[workKey];
    }

    function getWorkValidity(uint256 poolId, bytes32 workKey) external view returns (int256) {
        bool inInvalidMap = poolWork[poolId].invalidWorkKeys.contains(workKey);
        bool inValidMap = poolWork[poolId].workKeys.contains(workKey);

        if (inInvalidMap) {
            return 0;
        } else if (inValidMap) {
            return 1;
        } else {
            return -1;
        }
    }

    function getWorkKeys(uint256 poolId) external view returns (bytes32[] memory) {
        return poolWork[poolId].workKeys.values();
    }

    function getInvalidWorkKeys(uint256 poolId) external view returns (bytes32[] memory) {
        return poolWork[poolId].invalidWorkKeys.values();
    }

    function getWorkSince(uint256 poolId, uint256 timestamp) external view returns (bytes32[] memory) {
        int256 length = int256(poolWork[poolId].workKeys.length());
        int256 index = -1;
        for (int256 i = length - 1; i >= 0; i--) {
            bytes32 workKey = poolWork[poolId].workKeys.at(uint256(i));
            if (poolWork[poolId].work[workKey].timestamp < timestamp) {
                index = i;
                break;
            }
        }
        if (index == length - 1) {
            return new bytes32[](0);
        }
        bytes32[] memory result = new bytes32[](uint256(length - index - 1));
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = poolWork[poolId].workKeys.at(uint256(index + 1) + i);
        }
        return result;
    }

    function getInvalidWorkSince(uint256 poolId, uint256 timestamp) external view returns (bytes32[] memory) {
        int256 length = int256(poolWork[poolId].invalidWorkKeys.length());
        int256 index = -1;
        for (int256 i = length - 1; i >= 0; i--) {
            bytes32 workKey = poolWork[poolId].invalidWorkKeys.at(uint256(i));
            if (poolWork[poolId].work[workKey].timestamp < timestamp) {
                index = i;
                break;
            }
        }
        if (index == length - 1) {
            return new bytes32[](0);
        }
        bytes32[] memory result = new bytes32[](uint256(length - index - 1));
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = poolWork[poolId].invalidWorkKeys.at(uint256(index + 1) + i);
        }
        return result;
    }
}
