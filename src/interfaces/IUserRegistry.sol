// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUserRegistry {
    struct User {
        string delegatedPublicKey; // Ed25519 public key for app signing
        uint256 nonce; // Prevent replay attacks
        bool isActive; // Can revoke delegation
        uint256 registeredAt; // Timestamp
    }

    event UserRegistered(address indexed user, string publicKey);
    event DelegationRevoked(address indexed user);

    error UserRegistery__AlreadyRegistered();
    error UserRegistery__InvalidSignature();
    error UserRegistery__NotRegistered();

    function registerUser(bytes calldata signature, User memory user) external;
    function revokeDelegation() external;
    function hasActiveDelegation(address user) external view returns (bool);
    function getDelegatedKey(address user) external view returns (string memory);
    function getUserFromKey(string calldata publicKey) external view returns (address);
    function previewDelegatedKey(address user) external view returns (string memory);
}
