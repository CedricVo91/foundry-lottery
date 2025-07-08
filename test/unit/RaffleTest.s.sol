// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/Deploy.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {

    // ?? why public here and in all the state variables?
    Raffle public raffle; // ?? why public here and in all the state variables?
    HelperConfig public helperConfig; 
    address public PARTICIPANT = makeAddr("participant");
    uint256 public constant STARTING_BALANCE = 10 ether;

    // ?? why here no visibility needed? 
    uint256 entranceFee; 
    uint256 interval; 
    address vrfCoordinator; 
    bytes32 gasLane; 
    uint256 subscriptionId; 
    uint32 callbackGasLimit; 

    /* Events */
    event RaffleEntered(address indexed participant); // indexed so e.g. a frontend can easily find the "topics" part of log, not has to go through the "data" part of log
    event WinnerPicked(address indexed winner);


    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        entranceFee = config.entranceFee;
        vm.deal(PARTICIPANT,STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public  { // ask claude why these must be public and when they also need a view like the one above and when no view like the test below
        // Arrange
        vm.prank(PARTICIPANT);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector); // put the revert
        raffle.enterRaffle(); // participants enters the lottery/raffle without sending any money -> should revert
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {

        // Arrange 
        //hoax(PARTICIPANT, STARTING_BALANCE); -> not needed anymore as we have the vm.deal setup in our setup() function
        // we still need a vm.prank so that the contract knows that our participant is calling the next enter raffle function
        vm.prank(PARTICIPANT);
        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        address playerRecorded = raffle.getParticipant(0);
        assert(playerRecorded == PARTICIPANT);

        // the below does not work as we declared s_participants as private in our Raffle.sol contract -> thats why we need a getter function!
        //assert(raffle.s_participants[0] == PARTICIPANT);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PARTICIPANT);
        // Act
        vm.expectEmit(true,false,false, false, address(raffle)); // we tell foundry we will expect an event to emit
        emit RaffleEntered(PARTICIPANT); // we tell foundry that this is the exact event we expect to emit here
        // Assert 
        raffle.enterRaffle{value: entranceFee}(); // we call a function that emits the event we told foundry above we expect to emit
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}(); // isOpen: true && hasPlayers: true &&  hasBalance:true
        vm.warp(block.timestamp + interval + 1); // time has passed -> timeHasPassed: true
        vm.roll(block.number + 1); // one new block has been added -> timeHasPassed: true
        // the above are all needed so that we can call our performUpkeep
        raffle.performUpkeep(""); // we pick the winner by getting a random number and select our winner

        // Act 
        vm.expectRevert(Raffle.Raffle_RaffleNotOPEN.selector); // put the revert as we cant enter when we are selecting the winner
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();

    }



}
