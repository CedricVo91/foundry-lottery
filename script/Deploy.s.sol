// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

// when we deploy to an actual testnet - such as sepolia - this script is the only thing we gonna run!
contract DeployRaffle is Script {
    function run() public {
        // the run function here is just so we could run this Deploy Raffle Script as a standalone script!
        deployContract();

    }  // ?? why is this needed? shouldnt deploy contract below be in that run function as the run function is always run in the script?

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
            // important: this does NOT execute the CreateSubscription's run function!!
            CreateSubscription subscriptionContract = new CreateSubscription();
            // below we are updating our subscription id and vrf coordinator i.e. the subscriptionId is not zero anymore 
            // again, we do not call the createSubscriptionUsingConfig, and use our config from here to run the createSubscription function directly! 
            (config.subscriptionId, config.vrfCoordinator) = subscriptionContract.createSubscription(config.vrfCoordinator, config.account);
        }

        // 2. Fund the subscription id!
        FundSubscription fundSubscription = new FundSubscription();
        // again the run() function within the interactions.s.sol FundSubscription contract won't be called, we reuse our config from this file
        fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);

        


        vm.startBroadcast(config.account);
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
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

        // Important: we return the helperConfig contract here!, not the config struct
        return (raffle, helperConfig);
    }

}    