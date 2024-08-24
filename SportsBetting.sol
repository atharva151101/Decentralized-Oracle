// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "./CommonTypes.sol";
import "./OracleInterface.sol";
import "./SportsBettingInterface.sol";


/// @title A smart contract for sports betting
contract SportsBetting is SportsBettingInterface {
    
    address immutable public oracle ;

    MatchBettingInstance[] matchesList ;
    mapping(bytes32 => uint256) matchIdToIndexMap ;

    mapping(bytes32 => Bet[]) bets ;
    mapping(bytes32 => mapping(address => uint256)) addressToBetIndexMap;

    mapping(address => uint256) balances;


    event BettingOpenedForMatch(bytes32 matchId, string team1, string team2, uint256 canBetBefore);
    event BettingHaltedForMatch(bytes32 matchId);
    event BettingConcludedForMatch(bytes32 matchId, Result result);
    event BalanceUpdated(address Address, uint256 Balance);
    event BetPlaced(bytes32 matchId, uint256 amount, Result result, address betterAddress);
    
    
    error InsufficientBalance(uint256 balance, uint256 amount);



    modifier onlyOracle {
        require(msg.sender == oracle, "Only the oracle can call this function");
        _;
    }

    modifier validMatchId(bytes32 _id) {
        require(matchIdToIndexMap[_id] !=0 , "This Match Doesn't exists");
        _;
    }


    /// @notice the deployer is assigned as the oracle
    constructor() {
        oracle = msg.sender;
    }

    /// @notice add ethers as balance into the smart contract for placing bets
    function addBalance() external payable {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        emit BalanceUpdated(msg.sender, balances[msg.sender]); 
    }

    /// @notice place a bet on a match( Can also add balance simulataneously by sending ethers to this function). The balance is decreased while the bet is On.
    /// @param _id The unique match id of the match
    /// @param _amount The amount(in wei) of bet that the sender wants to place on the match
    /// @param result The reuslt on which the sender wants to bet on. ( 1 for Team1 winning, 2 for Team2 winning, 3 for Draw)
    function placeBet(bytes32 _id, uint256 _amount, Result result) validMatchId(_id) external payable {
        require(matchesList[matchIdToIndexMap[_id]-1].bettingStatus == MatchBettingStatus.Ongoing , 
            "The Betting Period for this Match is over as the match has already started or cancelled");

        require(block.timestamp < matchesList[matchIdToIndexMap[_id]-1].matchStartTime, 
            "The Betting Period for this Match is Over") ;

        require(result == Result.Team1 || result == Result.Team2 || result == Result.Draw ,
            "Invalid Result Value Provided for Bet");

        balances[msg.sender] = balances[msg.sender] + msg.value;

        if(_amount > balances[msg.sender])
            revert InsufficientBalance(balances[msg.sender], _amount);


        if(addressToBetIndexMap[_id][msg.sender] == 0)
            bets[_id].push(Bet(msg.sender, 0,0,0));
            addressToBetIndexMap[_id][msg.sender] = bets[_id].length;
        
        uint256 index = addressToBetIndexMap[_id][msg.sender] - 1;
        assert(bets[_id][index].betterAddress == msg.sender);
        
        balances[msg.sender] = balances[msg.sender] - _amount; 
        if(result == Result.Team1)
            bets[_id][index].team1_amount = bets[_id][index].team1_amount + _amount; 
        else if(result == Result.Team2)
            bets[_id][index].team2_amount = bets[_id][index].team2_amount + _amount; 
        else if(result == Result.Draw)
            bets[_id][index].draw_amount = bets[_id][index].draw_amount + _amount; 
        
        emit BetPlaced(_id, _amount, result,  msg.sender);
    }


    /// @notice withdraw some amount from the balance
    /// @param _amount The amount(in wei) the sender of transaction wants to withdraw. Has to be less than equal to the balance.
    function withdrawBalance(uint256 _amount) external payable {
        if(_amount > balances[msg.sender])
            revert InsufficientBalance(balances[msg.sender], _amount);

        balances[msg.sender] = balances[msg.sender] - _amount;

        payable(msg.sender).transfer(_amount);

        emit BalanceUpdated(msg.sender, balances[msg.sender]);
    }


    /// @notice To see what are all the bets that have been placed on a match
    /// @param matchId The id of the match whose bets we want to lookup
    /// @return all the bets for the particular match 
    function lookupBetsforMatch(bytes32 matchId) external view returns (Bet[] memory){
        return bets[matchId];
    }

    // A struct for returning values of the below function . (All amounts in wei)
    struct MyBet{
        bytes32 matchId;
        uint256 team1_amount;
        uint256 team2_amount;
        uint256 draw_amount;
    }

    /// @notice To get my current balance in the Sports Betting Contract
    /// @return amount Amount of Balance(in wei)
    function myBalance() external view returns(uint256 amount) {
        amount = balances[msg.sender];
    }

    /// @notice To check what all bets I(The transaction sender) have currently placed that have not yet concluded.
    /// @return myBets All the bets that the caller of the function(transaction sender) has currently place.
    function myCurrentBets() external view returns(MyBet[] memory myBets ) {
        uint count =0 ;

        for(uint i=0;i<matchesList.length;i++)
        {
            if(matchesList[i].bettingStatus != MatchBettingStatus.Concluded) {
                if(addressToBetIndexMap[matchesList[i].matchId][msg.sender] != 0)
                    count++;
            }
        }

        myBets = new MyBet[](count);

        uint iter=0;
        for(uint i=0;i<matchesList.length;i++) {
            if(matchesList[i].bettingStatus != MatchBettingStatus.Concluded) {
                if(addressToBetIndexMap[matchesList[i].matchId][msg.sender] != 0)
                {
                    bytes32 matchId = matchesList[i].matchId;
                    Bet memory bet = bets[matchId][addressToBetIndexMap[matchId][msg.sender]-1];
                    myBets[iter++] = MyBet(
                        matchId,
                        bet.team1_amount, 
                        bet.team2_amount,
                        bet.draw_amount
                        );
                }
            }
        } 
    }

    /// @notice Get the details regarding the betting Instance for a match
    /// @param matchId The id of the match whose bets we want to lookup
    /// @return team1 The name of first team in the match
    /// @return team2 The name of second team in the match
    /// @return startTime The start time of the match
    /// @return endTime The end time of the match
    /// @return canBetBefore The time before which a bet can be placed on the match (same as start time)
    function getBettingInstanceByMatchId(bytes32 matchId) external view returns(string memory team1, string memory team2, 
      uint256 startTime, uint256 endTime, uint256 canBetBefore) {
        MatchBettingInstance memory m = matchesList[matchIdToIndexMap[matchId]-1];
        return (m.team1, m.team2, m.matchStartTime, m.matchEndTime, m.matchStartTime);

    }

    /// @notice Get the ids(match ids) of all the betting instances for all the match that are currently open (Betting is open and the match hasnt yet started or concluded)
    /// @return matchIds all the matchIds for which betting is open.  
    function getAllOngoingBettingInstanceIds() external view returns(bytes32[] memory matchIds) {
        uint count = 0;
        for(uint i=0;i<matchesList.length; i++)
        {
            if(matchesList[i].bettingStatus == MatchBettingStatus.Ongoing && matchesList[i].matchStartTime > block.timestamp)
                count++;
        }
        matchIds = new bytes32[](count);

        uint iter = 0;
        for(uint i=0;i<matchesList.length; i++)
        {
            if(matchesList[i].bettingStatus == MatchBettingStatus.Ongoing && matchesList[i].matchStartTime > block.timestamp)
                matchIds[iter++]=matchesList[i].matchId ;
        }
    }

    /// @notice Get the ids of all the betting instance for all the matches
    /// @return matchIds the matchids of all the matches in the database(whose bets are open or halted or concluded)
    function getAllBettingInstanceIds() external view returns(bytes32[] memory matchIds) {
        matchIds = new bytes32[](matchesList.length);
        for(uint i=0;i<matchesList.length; i++)
        {
            matchIds[i]=matchesList[i].matchId ;
        }
    }

    
    /// @notice This function can only be called by the Oracle. This adds a new match and opens betting for that match
    /// @param _matchId The id of the new match fow whom betting will be opened
    /// @param _team1 The name of first team participating in the match.
    /// @param _team2 The name of second team participating in the match.
    /// @param _startTime The starting time for the match (Also the time upto which betting will be opened).
    /// @param _endTime The ending time for the match.
    function openBettingForMatch( bytes32 _matchId, string calldata _team1, string calldata _team2, uint256 _startTime, uint256 _endTime) 
        external onlyOracle override {
        matchesList.push(MatchBettingInstance(
            _matchId,
            _team1,
            _team2,
            _startTime,
            _endTime,
            MatchBettingStatus.Ongoing,
            Result.NoResult
        )) ;        

        matchIdToIndexMap[_matchId] = matchesList.length;

        emit BettingOpenedForMatch(_matchId, _team1, _team2, _startTime);
    } 


    /// @notice This function can only be called by the Oracle. This halts the betting for the match (typically because the match has started).
    /// @param _id The id of the match for which betting is to be halted.
    function haltBettingForMatch(bytes32 _id) external onlyOracle validMatchId(_id) override {
        matchesList[matchIdToIndexMap[_id]-1].bettingStatus = MatchBettingStatus.Halted;

        emit BettingHaltedForMatch(_id);
    }

    /// @notice This function can only be called by the Oracle. This concludes betting for the match(after the match has ended and the reulst of match is decided)
    /// @notice Also the balances for the addresses who had placed bets on this match are updated accordingly. Also a percentage of winnings is sent back to the oracle which in turn gives them to the voters as reward.
    /// @param _id The id of the match for which betting is to be concluded.
    /// @param _result The result of the match. (if result is NoResult then all the bets are refunded without any winner)
    function concludeBettingForMatch(bytes32 _id, Result _result) external onlyOracle validMatchId(_id) override {
        matchesList[matchIdToIndexMap[_id]-1].bettingStatus = MatchBettingStatus.Concluded;
        matchesList[matchIdToIndexMap[_id]-1].result = _result;

        uint256 totalBettingPool = 0;
        uint256 correctlyPredictedPool = 0;

        // If the result is NoResult i.e the match was cancelled. All the bets are refunded. 
        if(_result == Result.NoResult){
            for(uint i=0;i<bets[_id].length ;i++) {
                uint256 totalAmount = bets[_id][i].team1_amount + bets[_id][i].team2_amount + bets[_id][i].draw_amount ; 
                balances[bets[_id][i].betterAddress] = balances[bets[_id][i].betterAddress] + totalAmount ;
            }   
 
        }
        else {
            for(uint i=0;i<bets[_id].length ;i++) {
                totalBettingPool = totalBettingPool + bets[_id][i].team1_amount + bets[_id][i].team2_amount + bets[_id][i].draw_amount;
                if(_result == Result.Team1)
                    correctlyPredictedPool = correctlyPredictedPool + bets[_id][i].team1_amount; 
                else if(_result == Result.Team2)
                    correctlyPredictedPool = correctlyPredictedPool + bets[_id][i].team2_amount; 
                else if(_result == Result.Draw)
                    correctlyPredictedPool = correctlyPredictedPool + bets[_id][i].draw_amount;
            }

            uint256 totalWinnings = totalBettingPool - correctlyPredictedPool;
            OracleInterface(oracle).distributeVoterWinnigs{value : (totalWinnings/10)}(_id) ;

            // The bet winnings are calculated in proportion to amount of bets placed.
            for(uint i=0;i<bets[_id].length ;i++) {
                uint256 amountWon = 0 ;
                if(_result == Result.Team1)
                    amountWon = bets[_id][i].team1_amount + (((totalWinnings*9)/10)*bets[_id][i].team1_amount)/correctlyPredictedPool; 
                else if(_result == Result.Team2)
                    amountWon = bets[_id][i].team2_amount + (((totalWinnings*9)/10)*bets[_id][i].team2_amount)/correctlyPredictedPool; 
                else if(_result == Result.Draw)
                    amountWon = bets[_id][i].draw_amount + (((totalWinnings*9)/10)*bets[_id][i].draw_amount)/correctlyPredictedPool;

                balances[bets[_id][i].betterAddress] = balances[bets[_id][i].betterAddress] + amountWon;    
            }
        }
    }

    /// @notice This function can only be called by the oracle . Sends the total amount of bets that have been placed on a particular match.
    /// @param _id The id of the match whose total amount of bets placed is asked for.
    /// @return The amount(in Wei) of total bets placed on the match.
    function getTotalBettingPoolAmount(bytes32 _id) external view onlyOracle validMatchId(_id) override returns(uint256) {
        uint256 total = 0;

        for(uint i=0;i<bets[_id].length;i++)
        {
            total = total + bets[_id][i].team1_amount + bets[_id][i].team2_amount + bets[_id][i].draw_amount;
        }

        return total;
    }

}