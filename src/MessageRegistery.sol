// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageRegistery} from "./interfaces/IMessageRegistery.sol";
import {ECDSA} from "@oppenzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MessageRegistery is IMessageRegistery {
    using ECDSA for bytes32;

    error MessageRegistery__FailedToPostMessage();

    event MessagePosted(
        bytes32 indexed messageId,
        address indexed author,
        bytes32 indexed communityId,
        bytes32 channelId,
        string ipfsHash,
        uint256 timestamp
    );

    mapping(bytes32 => Message) public messages;
    function postMessage(
        bytes32 messageId,
        bytes32 communityId,
        bytes32 channelId,
        string memory ipfsHash,
        bytes calldata signature
    ) external {
        if (messages[messageId].id != bytes32(0)) {
            revert MessageRegistery__FailedToPostMessage();
        }

        // Verify signature (assuming the author is the signer)
        bytes32 message = keccak256(
            abi.encodePacked(
                "Post message with ID: ",
                messageId,
                " in community: ",
                communityId,
                " on channel: ",
                channelId,
                " with IPFS hash: ",
                ipfsHash
            )
        );

        address signer = message.recover(signature);
        if (signer != msg.sender) {
            revert MessageRegistery__FailedToPostMessage();
        }

        // Store message
        messages[messageId] = Message({
            id: messageId,
            author: msg.sender,
            communityId: communityId,
            channelId: channelId,
            ipfsHash: ipfsHash,
            timestamp: block.timestamp,
            parentId: bytes32(0)
        });

        emit MessagePosted(
            messageId,
            msg.sender,
            communityId,
            channelId,
            ipfsHash,
            block.timestamp
        );
    }
}