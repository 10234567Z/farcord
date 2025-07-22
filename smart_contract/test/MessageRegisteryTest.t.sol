// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MessageRegistery} from "src/MessageRegistery.sol";
import {IMessageRegistery} from "src/interfaces/IMessageRegistery.sol";
import {Test} from "forge-std/Test.sol";

contract MessageRegisteryTest is Test {
    MessageRegistery messageRegistery;

    function setUp() public {
        messageRegistery = new MessageRegistery();
    }
    
    address author = vm.addr(1);
    bytes32 communityId = keccak256("community");
    bytes32 channelId = keccak256("channel");
    string ipfsHash = "QmTestHash";
    bytes32 messageId = keccak256("msg1");

    event MessagePosted(
        bytes32 indexed messageId,
        address indexed author,
        bytes32 indexed communityId,
        bytes32 channelId,
        string ipfsHash,
        uint256 timestamp
    );

    function _signMessage(
        address signer,
        bytes32 messageId_,
        bytes32 communityId_,
        bytes32 channelId_,
        string memory ipfsHash_
    ) internal returns (bytes memory) {
        bytes32 message = keccak256(
            abi.encodePacked(
                "Post message with ID: ",
                messageId_,
                " in community: ",
                communityId_,
                " on channel: ",
                channelId_,
                " with IPFS hash: ",
                ipfsHash_
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, message);
        return abi.encodePacked(r, s, v);
    }

    function test_PostMessage_Success() public {
        vm.startPrank(author);
        bytes memory signature = _signMessage(author, messageId, communityId, channelId, ipfsHash);
        vm.expectEmit(true, true, true, true);
        emit MessagePosted(messageId, author, communityId, channelId, ipfsHash, block.timestamp);
        messageRegistery.postMessage(messageId, communityId, channelId, ipfsHash, signature);
        // Check storage
        (bytes32 id, address msgAuthor, bytes32 commId, bytes32 chanId, string memory hash, , bytes32 parentId) = messageRegistery.messages(messageId);
        assertEq(id, messageId);
        assertEq(msgAuthor, author);
        assertEq(commId, communityId);
        assertEq(chanId, channelId);
        assertEq(hash, ipfsHash);
        assertEq(parentId, bytes32(0));
        vm.stopPrank();
    }

    function test_PostMessage_RevertDuplicate() public {
        vm.startPrank(author);
        bytes memory signature = _signMessage(author, messageId, communityId, channelId, ipfsHash);
        messageRegistery.postMessage(messageId, communityId, channelId, ipfsHash, signature);
        // Try posting again with same messageId
        vm.expectRevert(MessageRegistery.MessageRegistery__FailedToPostMessage.selector);
        messageRegistery.postMessage(messageId, communityId, channelId, ipfsHash, signature);
        vm.stopPrank();
    }

    function test_PostMessage_RevertInvalidSignature() public {
        vm.startPrank(author);
        // Sign with wrong key (index 2)
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, message);
        bytes memory badSignature = abi.encodePacked(r, s, v);
        vm.expectRevert(MessageRegistery.MessageRegistery__FailedToPostMessage.selector);
        messageRegistery.postMessage(messageId, communityId, channelId, ipfsHash, badSignature);
        vm.stopPrank();
    }

    function test_PostMessage_RevertNotSender() public {
        // Signature is valid for author, but tx is sent by another address
        vm.startPrank(vm.addr(2));
        bytes memory signature = _signMessage(author, messageId, communityId, channelId, ipfsHash);
        vm.expectRevert(MessageRegistery.MessageRegistery__FailedToPostMessage.selector);
        messageRegistery.postMessage(messageId, communityId, channelId, ipfsHash, signature);
        vm.stopPrank();
    }
}

