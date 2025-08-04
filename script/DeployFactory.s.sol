// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/Factory.sol";

contract DeployFactory is Script {
    function run() external returns (Factory factory) {
        vm.startBroadcast();

        factory = new Factory();

        vm.stopBroadcast();
    }
}
