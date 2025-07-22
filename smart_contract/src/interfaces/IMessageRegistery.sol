// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageRegistery {
    struct Message {
        bytes32 id;
        address author;
        bytes32 communityId;
        bytes32 channelId;
        string ipfsHash;
        uint256 timestamp;
        bytes32 parentId; // for replies
    }

    function postMessage(
        bytes32 messageId,
        bytes32 communityId,
        bytes32 channelId,
        string calldata ipfsHash,
        bytes calldata signature
    ) external;
}
