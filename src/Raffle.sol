// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";



/** 
* @title A sample Raffle contract
* @author Cedric Vogt
* @notice This contract is for creating a sample raffle
* @dev Implements Chainlink VRFv2.5
*/



contract Raffle is VRFConsumerBaseV2Plus  {

    /* Errors */
    error Raffle_NotEnoughEthSent();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOPEN();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 numParticipants, uint256 raffleState);

    /* Type Declarations */
    enum RaffleState {
        OPEN,        // 0
        CALCULATING  // 1
    }

    /* State Variables*/
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee; 
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscribtionId;
    uint32 private immutable i_callbackGasLimit;
    // payable array because we want to send the winner the money
    // by declaring the array to have entries of type address payable we make sure that only payable type addresses are allowed to be pushed to the array
    address payable[] private s_participants;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    

    /* Events */
    event RaffleEntered(address indexed participant); // indexed so e.g. a frontend can easily find the "topics" part of log, not has to go through the "data" part of log
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint256 subscribtionId, 
        uint32 callbackGasLimit 
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscribtionId = subscribtionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp; // so that our lottery does not get kicked out directly when starting it 
        s_raffleState = RaffleState.OPEN; // initialize it to state zero of the enum
    }

    // user enters the Raffle aka Lottery - we have to pay to enter
    function enterRaffle() external payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent to enter raffle");
        // more gas efficient below
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOPEN();
        }
        
        // keep track of who entered the raffle
        s_participants.push(payable(msg.sender)); // ?? why do I need to enter the address as payable? because we defined the array as payable?
        emit RaffleEntered(msg.sender);
   }

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked
     * the following should be true in order for upkeedNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart lottery
     * @return - ignored
     */
   function checkUpkeep(bytes memory /* checkData*/) public view  returns (bool upkeepNeeded, bytes memory /*performData*/) { // we do public because we need it somewhere else
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval); // blocktimestamp: Unix timestamp (seconds since January 1, 1970) of when the current block was mine
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_participants.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, ""); // we wouldn't need to return upkeepNeeded as we have it defined in the line above  -> because we have a named return in our function definition (bool ukeepNeeded)
   }

    // 1. Get a random number
    // 2. Use a random number to pick a player
    // 3. Be automatically called
    // performUpkeep is the same as Pick a Winner i.e. pickWinner() but renamed to use chainlink automation
    function performUpkeep(bytes calldata /* performData */) external { // change public to external to save gas
        
        (bool upkeepNeeded,) = checkUpkeep(""); // we need a blank input ""
        if (!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_participants.length, uint256(s_raffleState)); 
        }

        s_raffleState = RaffleState.CALCULATING; // set the state to calculating so people can't be calling the enter raffle function when we decided to pick a winner!

        // Get our random number 2.5
        // our smart contract initiates a request for 1 random number (NUM_WORDS) by calling RandomWordsRequest
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscribtionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
            });

        // we request the random word from chainlinks VRF service and don't wait for any reply, we exit function immediately
        s_vrfCoordinator.requestRandomWords(request);
    }

    // The chainlink vrf oracle calls a designated callback function (e.g., `fulfillRandomWords`) on the consuming contract, delivering the results.
    // Special case: we inherit from an abstract contract, VRFConsumerBasev2Plus, we need to override the fulfillRandomWords function, as in the parent contract there is nothing in there 
    // Chainlink actually calls this function to give back our above requested random number
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        // Effect (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_participants.length;
        address payable recentWinner = s_participants[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN; // resetting the raffle so that players can reenter it again 
        s_participants = new address payable[](0); //  resetting our participants array
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);


        // Interactions (External Contract Interactions)
        // low level function call to send ether directly to the recentWinner - we didnt have to call a specific payable function of a contract e.g. fundMe.fund{}()
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success){
            revert Raffle_TransferFailed(); 
        }

       
    }

    /**

    /** Getter Functions */

    // these functions below help to get the state variables that are declared as private from other contracts like our test contracts
    function getEntranceFee() external view returns (uint256) { // for getters public is an overkill, as within the contract we don't need the getter function usually. Use external!
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getParticipant(uint256 indexOfParticipant) external view returns (address) {
        return s_participants[indexOfParticipant];
    }

}