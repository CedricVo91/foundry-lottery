// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/Deploy.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {

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
        DeployRaffle deployer = new DeployRaffle(); // IMPORTANT: forge test tells the setup() function we are on a local anvil chain -> so the config that gets used is always a local one with mock contracts (vrfcoordinator is always a mock one)
        (raffle, helperConfig) = deployer.deployContract(); // within our deployContract(), we deploy the config file a new!
        // However, here, we will always get the helperconfig that we already deployed in our deployContract() function -> getConfig just gets the struct config details we already deployed in our deployer contract
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); //  if (localNetworkConfig.vrfCoordinator != address(0)) -> is always true here in the test SetUp
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

    // check the upkeep works
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1); // time has passed -> timeHasPassed: true
        vm.roll(block.number + 1); // one new block has been added -> timeHasPassed: true

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // returns false as we cannot pick a winner without anyone funding i.e. enter the raffle

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}(); // isOpen: true && hasPlayers: true &&  hasBalance:true
        vm.warp(block.timestamp + interval + 1); // time has passed -> timeHasPassed: true
        vm.roll(block.number + 1); // one new block has been added -> timeHasPassed: true
        // the above are all needed so that we can call our performUpkeep
        raffle.performUpkeep(""); // we pick the winner by getting a random number and select our winner

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // returns false as we cannot enter when we are picking a winner i.e. run the performupkeep function        
        
        // Assert
        assert(!upkeepNeeded);
    }

    // test the perform Upkeep function

    function testPerformUpkeepCanOnlyRunIfCheckupIsTrue() public {
        // Arrange
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}(); 
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");
    }

    // ?? research what we test and how this works..why is the upkeep not needed?
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange 
        uint256 currentBalance = 0; // here we initiated these parameters as we will need it in the customer error that has parameters!
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}(); 
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1);
        _;
    }

    // what if we need to get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()  public raffleEntered {
        
        // Arrange
        //vm.prank(PARTICIPANT);
        //raffle.enterRaffle{value: entranceFee}(); 
        //vm.warp(block.timestamp + interval + 1); 
        //vm.roll(block.number + 1);

        // Act 
        vm.recordLogs(); // whatever logs are emitted below, keep them!
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];


        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId)>0);
        assert(uint256(raffleState) == 1);
    }


    // test fulfillrandomwords -> can only be called after perform upkeep function and on forked testnet or real testnet will fail without modifier as we are not the chainlink node that can call the fulfill random words on that contract
    
    // create modifier for real or forked real testnet
    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID){
            return;
        }
        _;
    }
    
    
    // fuzztest with randomRequest running 256 different numbers as randomRequestId entries in the function (all the different numbers available)
    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)   public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // the below only works as we are on a unit test via setup and forge test directly on a local anvil chain by default!
        // we are pretending to be the vrfCoordinator, normally that would be done by the chainlink nodeand the fulfillrandomwords will be called 
        // the only reason we can call the fulfillRandomWords function is because we deployed the local Mock contract!! We couldn't do this on a sepolia one, only anvil where we deploy our local one. On sepolia we instantiate with the vrf coordinator mock but cant call functions on it
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    // one last big unit test: end to end test that will serve as a baseline for the integration test
    function testFulfillrandomWordsPicksAWinnerResetsArraySendsMoney() public raffleEntered skipFork  {
        // Arrange
        uint256 additionalEntrants = 3; // 4 people total enter the lottery (plus the one in our modifier)
        uint256 startingIndex = 1; 
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < (startingIndex + additionalEntrants); i++){
            address newParticipant = address(uint160(i)); // from i=1 we can make it into an address by doing uint160(i)
            hoax(newParticipant, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs(); // whatever logs are emitted below, keep them!
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];  // get the request id

        // now we pretend to be the chainlink vrf node and call fulfillrandom words on the raffle with the requestid above
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        // is the winner correct
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);





    } 





}
