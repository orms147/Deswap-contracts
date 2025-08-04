// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/Router.sol";

contract DeployRouter is Script {
    function run() external returns (Router router) {
        vm.startBroadcast();

        address factoryAddress = 0x5dACaDBE6d07D4131030d473A97E2DF13cCe5C28;

        router = new Router(factoryAddress);

        vm.stopBroadcast();
    }
}
