// SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() external returns (HelperConfig helper, MinimalAccount minimalaccount) {
        (helper, minimalaccount) = deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        vm.startBroadcast(config.account);
        MinimalAccount minimalaccount = new MinimalAccount(config.entryPoint);
        minimalaccount.transferOwnership(config.account);
        vm.stopBroadcast();

        return (helper, minimalaccount);
    }
}
