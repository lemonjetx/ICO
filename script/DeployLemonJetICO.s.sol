// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LemonJetICO} from "../src/LemonJetICO.sol";

contract DeployLemonJetICO is Script {
    function run() public {
        address ljt = vm.envAddress("LJT_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address treasury = vm.envAddress("TREASURY");
        uint256 price = vm.envUint("PRICE");

        vm.startBroadcast();
        LemonJetICO ico = new LemonJetICO(ljt, usdc, treasury, price);
        vm.stopBroadcast();

        console.log("LemonJetICO:", address(ico));
    }
}
