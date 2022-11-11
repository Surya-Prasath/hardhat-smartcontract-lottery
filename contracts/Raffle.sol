// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

error Raffle_NotEnoughETHEntered();
error Raffle_TransferFailed();
error Raffle_NotOpen();
error Raffle_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/** 
 * @title A sample Raffle contract
 * @author Surya
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements chainlink VRF V2 and Keepers
 */
contract Raffle is VRFConsumerBaseV2, ConfirmedOwner, AutomationCompatibleInterface{

    /* Type declarations */
    enum RaffleState {
        OPEN, 
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    /* Lottery Variables */
    address private s_recentWinner;
    RaffleState private s_state;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2, 
        uint256 entranceFee, 
        bytes32 gasLane, 
        uint64 subscriptionId,
        uint32 callbackGasLimi,
        uint256 interval
        ) VRFConsumerBaseV2(vrfCoordinatorV2) ConfirmedOwner(msg.sender){
        i_entranceFee = entranceFee;  
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimi;
        s_state = RaffleState(0);
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    /* Functions */
    function enterRaffle() public payable {

        if(msg.value<i_entranceFee){
           revert Raffle_NotEnoughETHEntered();
        }
        if (s_state != RaffleState.OPEN) {
            revert Raffle_NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function pickRandomWinner() public {
        s_state = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, 
            i_subscriptionId, 
            REQUEST_CONFIRMATION, 
            i_callbackGasLimit,
            NUM_WORDS);

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_state = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle_TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call to check if the contract needs to be called.
     */

    function checkUpkeep(bytes memory /* checkData */) public view override returns(bool upKeepNeeded, bytes memory /* performData */){
        bool isOpen = RaffleState.OPEN == s_state;
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function performUpkeep(bytes calldata performData) external override{
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle_UpkeepNotNeeded(
                address(this).balance, 
                s_players.length, 
                uint256(s_state)
            );
        }
        pickRandomWinner();
    }

    /* View / Pure Functions */
    function getEntranceFee() public view returns(uint256){
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns(address){
        return s_players[index];
    }

    function getRecentWinner() public view returns(address){
        return s_recentWinner;
    }

    function getRaffleState() public view returns(RaffleState) {
        return s_state;
    }

    function getNumWords() public pure returns(uint256){
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns(uint256){
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns(uint256){
       return REQUEST_CONFIRMATION; 
    }

    function getInterval() public view returns(uint256){
        return i_interval;
    }
}