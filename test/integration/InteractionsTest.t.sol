// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Vm} from "forge-std/Vm.sol"; // for event testing
contract RaffleTestIntegration is Test {
    
    uint256 subId;
    address vrfCoordinator;
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;

    function setUp() external {

    }

    /// Standalone Script Execution Test ///
    // test if we can run our Interactions.s.sol test standalone: without the DeployRaffle Contract

    function testCreateSubscriptionUsingConfigStandalone() public {
        // Arrange
        createSubscription = new CreateSubscription();
        // Act
        (subId, vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
        // Assert
        assert(!(subId == 0));
        assert(vrfCoordinator != address(0));
        console.log(subId);
        console.log(vrfCoordinator);
    }

    function testFundSubscriptionUsingConfigStandalone() public {
        // Arrange
        fundSubscription = new FundSubscription();
        // Act
        fundSubscription.fundSubscriptionUsingConfig();
        // Assert
        // as there is no state variable or getter function in the vrf mock, we can check the events
        // re do the act part above just for learnings
        vm.recordLogs(); // start recording events
        fundSubscription.fundSubscriptionUsingConfig();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // easier
        // Assert
        assert(entries.length > 0); // If events were emitted, funding probably worked! 

        // harder: the below requires event looping /decoding
        //bytes32 oldBalance = entries[1]; // old balance in the event
        //bytes32 newBalance = entries[2]; // old balance + _amount in the event

        //assert((oldBalance + fundSubscription.FUND_AMOUNT) == newBalance);

    }

    function testAddConsumerUsingConfigStandalone() public {
        // Arrange 
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumer = new AddConsumer();
        addConsumer.addConsumerUsingConfig(mostRecentlyDeployed);

    }

}