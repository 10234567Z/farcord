// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { TokenGateManager } from "src/TokenGateManager.sol";

contract TokenGateManagerScript is Script {
    function run() external returns (TokenGateManager tokenGateManager) {
        vm.startBroadcast();
        tokenGateManager = new TokenGateManager();
        vm.stopBroadcast();
    }

    
}