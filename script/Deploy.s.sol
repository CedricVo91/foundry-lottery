// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";


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

        // 2. Fund the subscription id!
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);

        


        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit);
        vm.stopBroadcast();

        // after deploying the contract, we need to add it as a consumer to vrf contract
        AddConsumer addConsumer = new AddConsumer();
        // don't need to broadcast as we already have that in our addConsumer() function in interactions.s.sol
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId);

        return (raffle, helperConfig);
    }

}    