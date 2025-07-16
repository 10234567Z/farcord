// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@oppenzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@oppenzeppelin/contracts/access/Ownable.sol";

contract TokenGateManager is ReentrancyGuard, Ownable {
    error TokenGateManager__ZeroAddress();
    error TokenGateManager__InsufficientPayment();
    error TokenGateManager__InvalidCommunityName();
    error TokenGateManager__InvalidDescription();
    error TokenGateManager__NotEnoughBalance();

    struct TokenRequirement {
        address tokenAddress;
        uint256 minBalance;
    }

    struct NFTRequirement {
        address nftAddress;
        uint256 tokenId;
    }

    struct Requirements {
        TokenRequirement tokenRequirement;
        NFTRequirement nftRequirement;
    }

    struct Community {
        address owner;
        string name;
        string description;
        bool isActive;
        Requirements requirements;
        uint256 creationTime;
    }

    struct Channel {
        string name;
        string description;
        uint256 communityId;
        TokenRequirement tokenRequirement;
        NFTRequirement nftRequirement;
        uint256 creationTime;
        bool isActive;
    }



    mapping(uint256 => Community) public communities;
    uint256 public communityCount;

    constructor() Ownable(msg.sender) {}

    // New community
    // --> Set owner/nft owner/min balance requirement
    // --> Charges 0.001 eth as gas fees for creating the community
    function createCommunity(Community memory community) public payable nonReentrant {
        if (msg.value < 0.001 ether) {
            revert TokenGateManager__InsufficientPayment();
        }
        if (community.owner == address(0)) {
            revert TokenGateManager__ZeroAddress();
        }
        if (bytes(community.name).length == 0) {
            revert TokenGateManager__InvalidCommunityName();
        }
        if (bytes(community.description).length == 0) {
            revert TokenGateManager__InvalidDescription();
        }

        community.isActive = false;
        community.creationTime = block.timestamp;

        communities[communityCount] = community;
        communityCount++;
    }

    // New Channel
    // --> Set owner/nft owner/min balance requirement

    // Requesting to join/ verifies the requirement
    // --> Charges 0.001 eth as gas fees for joining the channel

    // Kicking someone out

    // Change the requirement


    // Withdraw fees function only availabel to owner of the contract
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert TokenGateManager__InsufficientPayment();
        }
        payable(owner()).transfer(balance);
    }
}
