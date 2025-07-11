// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {LinkToken} from "test/mocks/MockLink.sol";

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


// for the VRF lottery to work, we need to manually interact three way:
// 1. on the chainlink page, we have to create a subscription and get the subscription id -> to do this programmatically, we create the CreateSubscription Contract!
// 2. Then we need to manually fund the subscription with LINK -> programmatically: Fund Contract

contract CreateSubscription is Script {

    // the idea i.e. Desing Goal is that we can run the CreateSubscription Script on its own
    // Each Contract here should be able to run on its own as standalone scripts: e.g. forge script CreateSubscription --rpc-url $SEPOLIA_RPC_URL

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig(); 
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    // for our deploy script we only call this function and don't need the createSubscriptionUsingConfig -> however, when we want to run this script as a standalone, we need the function above so we have configs deployed!
    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("Creating subscription on chain Id:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription(); // this here calls the createSubscription on the VRFCoordinatorV2_5Mock contract by chainlink, either the official one deployed on sepolia by chainlink or our local anvil one!
        vm.stopBroadcast();

        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscription Id in your HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }

    // important insight: the run() function is ONLY run automaticcaly when we run the script directly from the command line with forge script CreateSubscription
    function run() public {
        createSubscriptionUsingConfig();
    }
}

// same design as above
contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // is this the same as 3 LINK // ether just is a way to handle big numbers: ether = 10^18. So we have 30^18 link, it has nothing to do with ethereum or ether
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig(); 
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account); 
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        // fundSubscription (as opposed to createSubscription() or addConsumer()) is a payable function -> it differs if we are on a testnet or not (see code below)
        if (block.chainid == LOCAL_CHAIN_ID){ // import Local_Chain_ID by inheriting from an imported abstract contract we defined before
            vm.startBroadcast(account);
            // on testnet we instantiate the mock contract via the official interface. The mock VRF pretends to be funded
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100); //Mock pretends to have more LINK. We don't need to approve a token transfer as its our own local one and we can just fund it with "lINK"
            vm.stopBroadcast();
        } else { // in our case on Sepolia! 
            vm.startBroadcast(account);
            // here we have a real LINK token and need to approve it to fund the vrf coordinator on sepolia
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId)); // ? why do we need to call a contract of token to fund another non token contract ? could we have a deep dive into this on abi encode and also what transfer and call is
            vm.stopBroadcast();
        }

    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}
// same design as above
contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed,vrfCoordinator, subId, account);
    }

    function addConsumer(address contractToAddtoVrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract:", vrfCoordinator);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(account);
        // the below is either our mock or the one on the sepolia testnet as we are allowed to call the addconsumer function on the official vrf testnet contract. In that case, we instantiate the contract with the VRFMOCK interface
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId,contractToAddtoVrf); // the function where we add our consumer i.e. our Raffle contract to the subscription we created in the contract before
        vm.stopBroadcast();
    }

    function run() external { // why here run is external and above its public?
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid); // we want our most recently deployed Raffle contract
        addConsumerUsingConfig(mostRecentlyDeployed); // the most recently deployed raffle contract will be entered into addConsumer as contractToAddtoVrf
    } 
}