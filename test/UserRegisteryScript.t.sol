// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UserRegistery} from "src/UserRegistery.sol";
import {IUserRegistry} from "src/interfaces/IUserRegistry.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

contract UserRegisteryScriptTest is Test {
    UserRegistery userRegistery;

    // address user1 = makeAddr("user1");
    // address user2 = makeAddr("user2");
    address user1 = vm.addr(1);
    address user2 = vm.addr(2);

    IUserRegistry.User user1Data =
        IUserRegistry.User({delegatedPublicKey: "", nonce: 0, isActive: false, registeredAt: 0});

    IUserRegistry.User user2Data =
        IUserRegistry.User({delegatedPublicKey: "", nonce: 0, isActive: false, registeredAt: 0});

    event UserRegistered(address indexed user, string publicKey);
    event DelegationRevoked(address indexed user);

    function setUp() public {
        userRegistery = new UserRegistery();
    }

    function test_RegisterUser_Success() public {
        vm.startPrank(user1);

        // Generate the message that user would sign
        string memory expectedKey = userRegistery.previewDelegatedKey(user1);
        bytes32 message = keccak256(
            abi.encodePacked("Delegate following signing key:", expectedKey, " for address: ", user1, " nonce: ", uint256(0))
        );

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, message);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect the event
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1, expectedKey);

        user1Data.delegatedPublicKey = expectedKey;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature, user1Data);

        // Verify registration
        assertTrue(userRegistery.hasActiveDelegation(user1));
        assertEq(userRegistery.getDelegatedKey(user1), expectedKey);
        assertEq(userRegistery.getUserFromKey(expectedKey), user1);

        vm.stopPrank();
    }

    function test_RegisterUser_RevertAlreadyRegistered() public {
        // Register user first
        vm.startPrank(user1);
        string memory expectedKey = userRegistery.previewDelegatedKey(user1);
        bytes32 message = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                expectedKey,
                " for address: ",
                user1,
                " nonce: ",
                uint256(0)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, message);
        bytes memory signature = abi.encodePacked(r, s, v);

        user1Data.delegatedPublicKey = expectedKey;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature, user1Data);

        // Try to register again
        vm.expectRevert(IUserRegistry.UserRegistery__AlreadyRegistered.selector);
        userRegistery.registerUser(signature, user1Data);
        vm.stopPrank();
    }

    function test_RegisterUser_RevertInvalidSignature() public {
        vm.startPrank(user1);

        // Create wrong signature (signed by different user)
        string memory expectedKey = userRegistery.previewDelegatedKey(user1);
        bytes32 message = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                expectedKey,
                " for address: ",
                user1,
                " nonce: ",
                uint256(0)
            )
        );

        // Sign with wrong private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, message);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(IUserRegistry.UserRegistery__InvalidSignature.selector);
        user1Data.delegatedPublicKey = expectedKey;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature, user1Data);

        vm.stopPrank();
    }

    function test_RevokeDelegation_Success() public {
        // Register user first
        vm.startPrank(user1);
        string memory expectedKey = userRegistery.previewDelegatedKey(user1);
        bytes32 message = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                expectedKey,
                " for address: ",
                user1,
                " nonce: ",
                uint256(0)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        user1Data.delegatedPublicKey = expectedKey;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature, user1Data);

        // Revoke delegation
        vm.expectEmit(true, false, false, false);
        emit DelegationRevoked(user1);

        userRegistery.revokeDelegation();

        // Verify revocation
        assertFalse(userRegistery.hasActiveDelegation(user1));
        assertEq(userRegistery.getUserFromKey(expectedKey), address(0));

        vm.stopPrank();
    }

    function test_RevokeDelegation_RevertNotRegistered() public {
        vm.startPrank(user1);

        vm.expectRevert(IUserRegistry.UserRegistery__NotRegistered.selector);
        userRegistery.revokeDelegation();

        vm.stopPrank();
    }

    function test_GetDelegatedKey_RevertNotRegistered() public {
        vm.expectRevert(IUserRegistry.UserRegistery__NotRegistered.selector);
        userRegistery.getDelegatedKey(user1);
    }

    function test_HasActiveDelegation_ReturnsFalseForUnregistered() public view {
        assertFalse(userRegistery.hasActiveDelegation(user1));
    }

    function test_GetUserFromKey_ReturnsZeroForInvalidKey() public view {
        assertEq(userRegistery.getUserFromKey("invalid_key"), address(0));
    }

    function test_MultipleUsersRegistration() public {
        // Register user1
        vm.startPrank(user1);
        string memory key1 = userRegistery.previewDelegatedKey(user1);
        bytes32 message1 = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                key1,
                " for address: ",
                user1,
                " nonce: ",
                uint256(0)
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, message1);
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        user1Data.delegatedPublicKey = key1;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature1, user1Data);
        vm.stopPrank();

        // Register user2
        vm.startPrank(user2);
        string memory key2 = userRegistery.previewDelegatedKey(user2);
        bytes32 message2 = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                key2,
                " for address: ",
                user2,
                " nonce: ",
                uint256(0)
            )
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(2, message2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        user2Data.delegatedPublicKey = key2;
        user2Data.nonce = 0;
        user2Data.isActive = true;
        user2Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature2, user2Data);
        vm.stopPrank();

        // Verify both users are registered with different keys
        assertTrue(userRegistery.hasActiveDelegation(user1));
        assertTrue(userRegistery.hasActiveDelegation(user2));
        assertNotEq(key1, key2);
        assertEq(userRegistery.getUserFromKey(key1), user1);
        assertEq(userRegistery.getUserFromKey(key2), user2);
    }

    function test_UniqueKeyGeneration() public {
        // Get keys for same user at different times
        string memory key1 = userRegistery.previewDelegatedKey(user1);

        // Advance time
        vm.warp(block.timestamp + 1);

        string memory key2 = userRegistery.previewDelegatedKey(user1);

        // Keys should be different due to timestamp
        assertNotEq(key1, key2);
    }

    function test_NonceIncrement() public {
        vm.startPrank(user1);

        // Check initial nonce
        (, uint256 initialNonce,,) = userRegistery.users(user1);
        assertEq(initialNonce, 0);

        // Register user
        string memory expectedKey = userRegistery.previewDelegatedKey(user1);
        bytes32 message = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                expectedKey,
                " for address: ",
                user1,
                " nonce: ",
                uint256(0)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        user1Data.delegatedPublicKey = expectedKey;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature, user1Data);

        // Check nonce incremented
        (, uint256 newNonce,,) = userRegistery.users(user1);
        assertEq(newNonce, 1);

        vm.stopPrank();
    }

    function test_RegisteredAtTimestamp() public {
        vm.startPrank(user1);

        uint256 registrationTime = block.timestamp;

        string memory expectedKey = userRegistery.previewDelegatedKey(user1);
        bytes32 message = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                expectedKey,
                " for address: ",
                user1,
                " nonce: ",
                uint256(0)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        user1Data.delegatedPublicKey = expectedKey;
        user1Data.nonce = 0;
        user1Data.isActive = true;
        user1Data.registeredAt = block.timestamp;

        // Register user
        userRegistery.registerUser(signature, user1Data);

        (,,, uint256 registeredAt) = userRegistery.users(user1);
        assertEq(registeredAt, registrationTime);

        vm.stopPrank();
    }
}
