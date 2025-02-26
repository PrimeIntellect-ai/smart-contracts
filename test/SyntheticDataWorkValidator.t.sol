// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SyntheticDataWorkValidator.sol";

contract SyntheticDataWorkValidatorTest is Test {
    SyntheticDataWorkValidator public validator;
    address public computePool;
    address public provider;
    address public nodeId;
    uint256 public constant DOMAIN_ID = 1;
    uint256 public constant POOL_ID = 1;
    uint256 public constant WORK_VALIDITY_PERIOD = 1 days;

    function setUp() public {
        computePool = address(this);
        provider = address(0x1);
        nodeId = address(0x2);
        validator = new SyntheticDataWorkValidator(DOMAIN_ID, computePool, WORK_VALIDITY_PERIOD);
    }

    function testSubmitWork() public {
        bytes32 workKey = keccak256("test_work");
        bytes memory data = abi.encodePacked(workKey);

        vm.warp(42);
        bool success = validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, data);
        assertTrue(success, "Work submission should succeed");

        bytes32[] memory workKeys = validator.getWorkKeys(POOL_ID);
        assertEq(workKeys.length, 1, "Should have one work key");
        assertEq(workKeys[0], workKey, "Work key should match");

        SyntheticDataWorkValidator.WorkInfo memory info = validator.getWorkInfo(POOL_ID, workKey);
        assertEq(info.provider, provider, "Provider should match");
        assertEq(info.nodeId, nodeId, "Node ID should match");
        assertEq(uint256(info.timestamp), 42, "Timestamp should match");
    }

    function testCannotSubmitDuplicateWork() public {
        bytes32 workKey = keccak256("test_work");
        bytes memory data = abi.encodePacked(workKey);

        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, data);

        vm.expectRevert("Work already submitted");
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, data);
    }

    function testInvalidateWork() public {
        bytes32 workKey = keccak256("test_work");
        bytes memory data = abi.encodePacked(workKey);

        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, data);

        (address returnedProvider, address returnedNodeId) = validator.invalidateWork(POOL_ID, data);

        assertEq(returnedProvider, provider, "Returned provider should match");
        assertEq(returnedNodeId, nodeId, "Returned nodeId should match");

        bytes32[] memory workKeys = validator.getWorkKeys(POOL_ID);
        assertEq(workKeys.length, 0, "Should have no active work keys");

        bytes32[] memory invalidWorkKeys = validator.getInvalidWorkKeys(POOL_ID);
        assertEq(invalidWorkKeys.length, 1, "Should have one invalid work key");
        assertEq(invalidWorkKeys[0], workKey, "Invalid work key should match");
    }

    function testCannotInvalidateAfterValidityPeriod() public {
        bytes32 workKey = keccak256("test_work");
        bytes memory data = abi.encodePacked(workKey);

        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, data);

        // Move time forward beyond validity period
        skip(WORK_VALIDITY_PERIOD + 1);

        vm.expectRevert("Work invalidation window has lapsed");
        validator.invalidateWork(POOL_ID, data);
    }

    function testGetWorkSince() public {
        bytes32 workKey1 = keccak256("test_work_1");
        bytes32 workKey2 = keccak256("test_work_2");

        bytes32[] memory recentWork = validator.getWorkSince(POOL_ID, 0);
        assertEq(recentWork.length, 0, "Should have no work");

        vm.warp(1000);
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, abi.encodePacked(workKey1));

        vm.warp(2000);
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, abi.encodePacked(workKey2));

        recentWork = validator.getWorkSince(POOL_ID, 2001);
        assertEq(recentWork.length, 0, "Should have no work");

        recentWork = validator.getWorkSince(POOL_ID, 1500);
        assertEq(recentWork.length, 1, "Should have one recent work");
        assertEq(recentWork[0], workKey2, "Recent work key should match");

        recentWork = validator.getWorkSince(POOL_ID, 1000);
        assertEq(recentWork.length, 2, "Should have two recent work items");
        assertEq(recentWork[0], workKey1, "First work key should match");
        assertEq(recentWork[1], workKey2, "Second work key should match");
    }

    function testGetInvalidWorkSince() public {
        bytes32 workKey1 = keccak256("test_work_1");
        bytes32 workKey2 = keccak256("test_work_2");
        bytes32 workKey3 = keccak256("test_work_3");
        bytes32 workKey4 = keccak256("test_work_4");

        vm.warp(1000);
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, abi.encodePacked(workKey1));
        vm.warp(2000);
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, abi.encodePacked(workKey2));
        vm.warp(3000);
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, abi.encodePacked(workKey3));
        vm.warp(4000);
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, abi.encodePacked(workKey4));

        bytes32[] memory recentInvalidWork = validator.getInvalidWorkSince(POOL_ID, 0);
        assertEq(recentInvalidWork.length, 0, "Should have one recent invalid work");

        validator.invalidateWork(POOL_ID, abi.encodePacked(workKey2));
        validator.invalidateWork(POOL_ID, abi.encodePacked(workKey3));

        recentInvalidWork = validator.getInvalidWorkSince(POOL_ID, 3001);
        assertEq(recentInvalidWork.length, 0, "Should have one recent invalid work");

        recentInvalidWork = validator.getInvalidWorkSince(POOL_ID, 3000);
        assertEq(recentInvalidWork.length, 1, "Should have one recent invalid work");
        assertEq(recentInvalidWork[0], workKey3, "Recent invalid work key should match");

        recentInvalidWork = validator.getInvalidWorkSince(POOL_ID, 0);
        assertEq(recentInvalidWork.length, 2, "Should have two recent invalid work");
        assertEq(recentInvalidWork[0], workKey2, "First invalid work key should match");
        assertEq(recentInvalidWork[1], workKey3, "Second invalid work key should match");
    }

    function testUnauthorizedSubmission() public {
        bytes32 workKey = keccak256("test_work");
        bytes memory data = abi.encodePacked(workKey);

        // Set msg.sender to a different address
        vm.prank(address(0x3));

        vm.expectRevert("Unauthorized");
        validator.submitWork(DOMAIN_ID, POOL_ID, provider, nodeId, data);
    }

    function testInvalidDomainId() public {
        bytes32 workKey = keccak256("test_work");
        bytes memory data = abi.encodePacked(workKey);

        vm.expectRevert("Invalid domainId");
        validator.submitWork(DOMAIN_ID + 1, POOL_ID, provider, nodeId, data);
    }
}
