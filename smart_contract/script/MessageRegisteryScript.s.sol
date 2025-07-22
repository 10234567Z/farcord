// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {MessageRegistery} from "src/MessageRegistery.sol";
import {Script} from "forge-std/Script.sol";

contract MessageRegisteryScript is Script {
    function run() external returns (MessageRegistery messageRegistery) {
        vm.startBroadcast();
        messageRegistery = new MessageRegistery();
        vm.stopBroadcast();
    }
}