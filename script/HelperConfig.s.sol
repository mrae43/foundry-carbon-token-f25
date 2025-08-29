// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error UnsupportedNetwork();

    struct NetworkConfig {
        address initialOwner;
        uint256 deployerPrivateKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getAnvilConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            revert UnsupportedNetwork();
        }
    }

    function getAnvilConfig() internal view returns (NetworkConfig memory) {
        // Default to first anvil account
        uint256 privateKey = vm.envOr("PRIVATE_KEY", uint256(0xa11ce));
        address owner = vm.envOr("INITIAL_OWNER", vm.addr(privateKey));
        return
            NetworkConfig({
                initialOwner: owner,
                deployerPrivateKey: privateKey
            });
    }

    function getSepoliaConfig() internal view returns (NetworkConfig memory) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("INITIAL_OWNER");
        return
            NetworkConfig({
                initialOwner: owner,
                deployerPrivateKey: privateKey
            });
    }

    function getActiveNetworkConfig()
        external
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }
}
