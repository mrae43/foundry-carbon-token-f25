// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "forge-std/Script.sol";
import {CreditUnitRegistry} from "../src/registry/CreditUnitRegistry.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployContract is Script {
    function run() external returns (CreditUnitRegistry) {
        // Load config for current chain
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveNetworkConfig();

        // Deploy using Foundry broadcast
        vm.startBroadcast(config.deployerPrivateKey);
        CreditUnitRegistry creditUnitRegistry = new CreditUnitRegistry(
            config.initialOwner
        );
        vm.stopBroadcast();

        // Logs for debugging
        console2.log("Network Chain ID:", block.chainid);
        console2.log("Deployer Address:", vm.addr(config.deployerPrivateKey));
        console2.log("Initial Owner:", config.initialOwner);
        console2.log(
            "CreditUnitRegistry deployed at:",
            address(creditUnitRegistry)
        );

        return creditUnitRegistry;
    }
}
