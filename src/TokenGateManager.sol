// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@oppenzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@oppenzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@oppenzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@oppenzeppelin/contracts/interfaces/IERC721.sol";

contract TokenGateManager is ReentrancyGuard, Ownable {
    /**
     *    ERRRORS
     */
    error TokenGateManager__ZeroAddress();
    error TokenGateManager__InsufficientPayment();
    error TokenGateManager__InvalidCommunityName();
    error TokenGateManager__InvalidDescription();
    error TokenGateManager__NotEnoughBalance();
    error TokenGateManager__CommunityNotActive();
    error TokenGateManager__NotTheOwner();
    error TokenGateManager__NotQualified();

    // Channel Errors
    error TokenGateManager__ChannelNotActive();
    error TokenGateManager__InvalidChannelName();
    error TokenGateManager__InvalidChannelDescription();

    /**
     *   EVENTS
     */
    event CommunityCreated(uint256 indexed communityId, address indexed owner, string name);
    event ChannelCreated(uint256 indexed channelId, uint256 indexed communityId, string name);
    event CommunityUpdated(uint256 indexed communityId, string name, string description);
    event ChannelUpdated(uint256 indexed channelId, string name, string description);
    event CommunityJoined(uint256 indexed communityId, address indexed user);
    event ChannelDeleted();
    event CommunityDeleted();
    event UserKicked(uint256 indexed communityId, address indexed user);

    /**
     *   STRUCTS AND DEFINITIONS
     */
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
    mapping(uint256 => Channel) public channels;
    mapping(uint256 => uint256[]) public communityChannels; // communityId to channelIds
    mapping(address => uint256[]) public userCommunities; // user address to communityIds
    uint256 public communityCount;
    uint256 public channelCount;

    // User Specific Definitions/Data

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

        emit CommunityCreated(communityCount - 1, community.owner, community.name);
        communities[communityCount] = community;
        communityCount++;
    }

    // New Channel
    // --> Set owner/nft owner/min balance requirement
    function createChannel(Channel memory channel) public nonReentrant {
        if (channel.communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[channel.communityId];
        if (community.owner != msg.sender) {
            revert TokenGateManager__NotTheOwner();
        }
        if (community.isActive == false) {
            revert TokenGateManager__CommunityNotActive();
        }
        if (bytes(channel.name).length == 0) {
            revert TokenGateManager__InvalidChannelName();
        }
        if (bytes(channel.description).length == 0) {
            revert TokenGateManager__InvalidChannelDescription();
        }

        channel.isActive = false;
        channel.creationTime = block.timestamp;
        emit CommunityCreated(communityCount - 1, community.owner, community.name);
        channels[channelCount] = channel;
        communityChannels[channel.communityId].push(channelCount);
        channelCount++;
    }

    // Requesting to join/ verifies the requirement
    // --> Charges 0.001 eth as gas fees for joining the channel
    function joinCommunity(uint256 communityId) public payable nonReentrant {
        if (msg.value < 0.001 ether) {
            revert TokenGateManager__InsufficientPayment();
        }
        if (communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[communityId];
        if (!community.isActive) {
            revert TokenGateManager__CommunityNotActive();
        }

        // Check requirements
        if (!_checkRequirements(community.requirements, msg.sender)) {
            revert TokenGateManager__NotEnoughBalance();
        }

        // Logic to add user to the community can be added here
        userCommunities[msg.sender].push(communityId);
        emit CommunityJoined(communityId, msg.sender);
    }

    // Kicking someone out
    // --> Only the owner of the community can kick someone out
    function kickUser(uint256 communityId, address user) public nonReentrant {
        if (communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[communityId];
        if (community.owner != msg.sender) {
            revert TokenGateManager__NotTheOwner();
        }
        if (!community.isActive) {
            revert TokenGateManager__CommunityNotActive();
        }
        if (bytes(community.name).length == 0) {
            revert TokenGateManager__InvalidCommunityName();
        }
        if (bytes(community.description).length == 0) {
            revert TokenGateManager__InvalidDescription();
        }
        if (user == address(0)) {
            revert TokenGateManager__ZeroAddress();
        }
        // Logic to remove user from the community can be added here
        uint256[] storage userComms = userCommunities[user];
        for (uint256 i = 0; i < userComms.length; i++) {
            if (userComms[i] == communityId) {
                userComms[i] = userComms[userComms.length - 1];
                userComms.pop();
                emit UserKicked(communityId, user);
                break;
            }
        }
        // Remove channels associated with the community
        uint256[] storage commChannels = communityChannels[communityId];
        for (uint256 i = 0; i < commChannels.length; i++) {
            uint256 channelId = commChannels[i];
            Channel memory channel = channels[channelId];
            if (channel.isActive) {
                channel.isActive = false;
                channels[channelId] = channel;
                emit ChannelDeleted();
            }
        }
        delete communityChannels[communityId];
    }

    // Change the requirement
    function updateCommunityRequirements(uint256 communityId, Requirements memory requirements) public nonReentrant {
        if (communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[communityId];
        if (community.owner != msg.sender) {
            revert TokenGateManager__NotTheOwner();
        }
        if (!community.isActive) {
            revert TokenGateManager__CommunityNotActive();
        }
        if (bytes(community.name).length == 0) {
            revert TokenGateManager__InvalidCommunityName();
        }
        if (bytes(community.description).length == 0) {
            revert TokenGateManager__InvalidDescription();
        }

        // Update requirements
        community.requirements = requirements;
        communities[communityId] = community;
        emit CommunityUpdated(communityId, community.name, community.description);
    }

    // Delete the Community
    // --> Only the owner of the community can delete it
    function deleteCommunity(uint256 communityId) public nonReentrant {
        if (communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[communityId];
        if (community.owner != msg.sender) {
            revert TokenGateManager__NotTheOwner();
        }
        if (!community.isActive) {
            revert TokenGateManager__CommunityNotActive();
        }
        if (bytes(community.name).length == 0) {
            revert TokenGateManager__InvalidCommunityName();
        }
        if (bytes(community.description).length == 0) {
            revert TokenGateManager__InvalidDescription();
        }
        // Logic to remove the community can be added here
        community.isActive = false;
        communities[communityId] = community;
        // Remove community from userCommunities mapping
        uint256[] storage userComms = userCommunities[msg.sender];
        for (uint256 i = 0; i < userComms.length; i++) {
            if (userComms[i] == communityId) {
                userComms[i] = userComms[userComms.length - 1];
                userComms.pop();
                break;
            }
        }
        // Remove channels associated with the community
        uint256[] storage commChannels = communityChannels[communityId];
        for (uint256 i = 0; i < commChannels.length; i++) {
            uint256 channelId = commChannels[i];
            Channel memory channel = channels[channelId];
            if (channel.isActive) {
                channel.isActive = false;
                channels[channelId] = channel;
                emit ChannelDeleted();
            }
        }
        delete communityChannels[communityId];
        emit CommunityDeleted();
    }

    // Delete the Channel
    // --> Only the owner of the community can delete it
    function deleteChannel(uint256 channelId) public nonReentrant {
        if (channelId >= channelCount) {
            revert TokenGateManager__InvalidChannelName();
        }
        Channel memory channel = channels[channelId];
        if (channel.communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[channel.communityId];
        if (community.owner != msg.sender) {
            revert TokenGateManager__NotTheOwner();
        }
        if (!channel.isActive) {
            revert TokenGateManager__ChannelNotActive();
        }
        if (bytes(channel.name).length == 0) {
            revert TokenGateManager__InvalidChannelName();
        }
        if (bytes(channel.description).length == 0) {
            revert TokenGateManager__InvalidChannelDescription();
        }
        // Logic to remove the channel from the community can be added here
        channel.isActive = false;
        channels[channelId] = channel;
        // Remove channel from communityChannels mapping
        uint256[] storage commChannels = communityChannels[channel.communityId];
        for (uint256 i = 0; i < commChannels.length; i++) {
            if (commChannels[i] == channelId) {
                commChannels[i] = commChannels[commChannels.length - 1];
                commChannels.pop();
                break;
            }
        }
        emit ChannelDeleted();
    }

    // Leave community
    function leaveCommunity(uint256 communityId) public nonReentrant {
        if (communityId >= communityCount) {
            revert TokenGateManager__InvalidCommunityName();
        }
        Community memory community = communities[communityId];
        if (!community.isActive) {
            revert TokenGateManager__CommunityNotActive();
        }

        // Logic to remove user from the community can be added here
        uint256[] storage userComms = userCommunities[msg.sender];
        for (uint256 i = 0; i < userComms.length; i++) {
            if (userComms[i] == communityId) {
                userComms[i] = userComms[userComms.length - 1];
                userComms.pop();
                break;
            }
        }
    }

    // Withdraw fees function only availabel to owner of the contract
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert TokenGateManager__InsufficientPayment();
        }
        payable(owner()).transfer(balance);
    }

    /**
     *   INTERNAL FUNCTIONS
     */

    // Check Requirements
    function _checkRequirements(Requirements memory requirements, address user) internal view returns (bool) {
        // Check token balance
        if (requirements.tokenRequirement.tokenAddress != address(0)) {
            uint256 userBalance = IERC20(requirements.tokenRequirement.tokenAddress).balanceOf(user);
            if (userBalance < requirements.tokenRequirement.minBalance) {
                return false;
            }
        }

        // Check NFT ownership
        if (requirements.nftRequirement.nftAddress != address(0)) {
            bool ownsNFT =
                IERC721(requirements.nftRequirement.nftAddress).ownerOf(requirements.nftRequirement.tokenId) == user;
            if (!ownsNFT) {
                return false;
            }
        }

        return true;
    }
}
