// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "@oppenzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IUserRegistry} from "./interfaces/IUserRegistry.sol";

contract UserRegistery is IUserRegistry {
    using ECDSA for bytes32;

    mapping(address => User) public users;
    mapping(string => address) public publicKeyToUser;

    /**
     * @dev Register user and delegate signing authority to app-generated key
     * @param signature User's signature authorizing the delegation
     */
    function registerUser(bytes calldata signature, User memory user) external {
        if (users[msg.sender].isActive) revert UserRegistery__AlreadyRegistered();

        string memory delegatedPublicKey = _generateUniquePublicKey(msg.sender);

        bytes32 message = keccak256(
            abi.encodePacked(
                "Delegate following signing key:",
                delegatedPublicKey,
                " for address: ",
                msg.sender,
                " nonce: ",
                user.nonce
            )
        );

        // Verify signature
        address signer = message.recover(signature);
        if (signer != msg.sender) revert UserRegistery__InvalidSignature();

        // Store delegation
        users[msg.sender] = User({
            delegatedPublicKey: delegatedPublicKey,
            nonce: users[msg.sender].nonce + 1,
            isActive: true,
            registeredAt: block.timestamp
        });

        publicKeyToUser[delegatedPublicKey] = msg.sender;

        emit UserRegistered(msg.sender, delegatedPublicKey);
    }

    /**
     * @dev Generate unique public key for user (deterministic but unpredictable)
     */
    function _generateUniquePublicKey(address user) internal view returns (string memory) {
        bytes32 keyHash = keccak256(
            abi.encodePacked(user, block.timestamp, block.prevrandao, address(this), "farcord_delegation_key")
        );

        // Convert to hex string (simulating Ed25519 public key format)
        return _bytes32ToHexString(keyHash);
    }

    /**
     * @dev Convert bytes32 to hex string
     */
    function _bytes32ToHexString(bytes32 data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);

        for (uint256 i = 0; i < 32; i++) {
            str[i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[1 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }

        return string(str);
    }

    /**
     * @dev Revoke delegation - user can no longer post messages via app
     */
    function revokeDelegation() external {
        if (!users[msg.sender].isActive) revert UserRegistery__NotRegistered();

        string memory oldKey = users[msg.sender].delegatedPublicKey;
        delete publicKeyToUser[oldKey];
        users[msg.sender].isActive = false;

        emit DelegationRevoked(msg.sender);
    }

    /**
     * @dev Check if user has active delegation
     */
    function hasActiveDelegation(address user) external view returns (bool) {
        return users[user].isActive;
    }

    /**
     * @dev Get user's delegated public key
     */
    function getDelegatedKey(address user) external view returns (string memory) {
        if (!users[user].isActive) revert UserRegistery__NotRegistered();
        return users[user].delegatedPublicKey;
    }

    /**
     * @dev Get user address from their delegated public key
     */
    function getUserFromKey(string calldata publicKey) external view returns (address) {
        return publicKeyToUser[publicKey];
    }

    /**
     * @dev Preview what delegated key would be generated for a user (for testing)
     */
    function previewDelegatedKey(address user) external view returns (string memory) {
        return _generateUniquePublicKey(user);
    }
}
