// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "lib/forge-std/src/Script.sol";
import {FactoryToken} from "../src/FactoryToken.sol";

contract DeployFactoryToken is Script {
    function run() external returns (FactoryToken) {
        vm.startBroadcast();

        FactoryToken ftk = new FactoryToken(); 

        vm.stopBroadcast();

        return ftk;
    } 
}