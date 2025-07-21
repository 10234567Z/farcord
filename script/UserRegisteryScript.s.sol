// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UserRegistery} from "src/UserRegistery.sol";
import {Script} from "forge-std/Script.sol";


contract UserRegisteryScript is Script {
    function run() external returns (UserRegistery userRegistery) {
        vm.startBroadcast();
        userRegistery = new UserRegistery();
        vm.stopBroadcast();
    }
}