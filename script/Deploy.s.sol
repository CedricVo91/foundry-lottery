// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription} from "script/Interactions.s.sol";


contract DeployRaffle is Script {
    function run() public {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local -> deploy mocks -> get local config
        // sepolia -> getSepoliaConfig
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
    
        // for the vrf we need to:
        // 1. Create a subscription
        // 2. Fund the subcription with Link tokens

        // 1. Create the subscription programmatically (that is without doing it manually on the UI webpage )
        if (config.subscriptionId == 0) {
            // create subscription
            CreateSubscription subscriptionContract = new CreateSubscription();
            // below we are updating our subscription id and vrf coordinator i.e. the subscriptionId is not zero anymore 
            (config.subscriptionId, config.vrfCoordinator) = subscriptionContract.createSubscription(config.vrfCoordinator);

        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit);
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }

}    