// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {SavingsVault} from "../src/SavingsVault.sol";
import {console} from "forge-std/console.sol";

contract DeploySavingsVault is Script {
    function run() external {
        // No private key reading here - will be provided via CLI
        console.log("Deploying SavingsVault to Sepolia...");

        vm.startBroadcast();

        SavingsVault vault = new SavingsVault();

        vm.stopBroadcast();

        console.log(" SavingsVault deployed successfully!");
        console.log(" Contract address:", address(vault));
        console.log(" Owner:", vault.owner());
        console.log(" Max Deposit:", vault.maxDeposit());
    }
}
