// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "./CommonTypes.sol";
import "./OracleInterface.sol";
import "./SportsBetting.sol";

/// @title This contract acts as the Oracle for the sports betting contract.
contract Oracle is OracleInterface {

    address public owner;
    address immutable public bettingContract;
    Match[] matchesList; 
    mapping(bytes32 => uint256) matchIdtoIndexMap;
    mapping(bytes32 => ChallengeParameters) public matchChallengeParameters;
    mapping(bytes32 => mapping(address => bool)) alreadyVoted;
    mapping(bytes32 => Vote[]) votes;

    uint private randomCounter = 1;
    
    event BettingContractDeployed(address bettingContract);
    event NewMatchAdded(bytes32 MatchId, string Team1, string Team2, uint256 StartTime, uint256 EndTime);
    event MatchCancelled(bytes32 MatchId, string Team1, string Team2);
    event MatchStarted(bytes32 MatchId, string Team1, string Team2);
    event MatchEnded(bytes32 MatchId, string Team1, string Team2);
    event MatchChallengeAnnouncement(bytes32 MatchId, bytes32 challenge, uint256 difficulty, uint256 votingFee, uint256 votingEndTime);
    event MatchResultDecided(bytes32 MatchId, string Team1, string Team2, Result result);
    event VoteSubmitted(bytes32 MatchId, address voteSender, string nonce, Result vote);
    

    error MatchAlreadyStarted(bytes32 _id);
    error MatchAlreadyCancelled(bytes32 _id);
    error MatchAlreadyEnded(bytes32 _id);
    error MatchAlreadyDecided(bytes32 _id);
    error AlreadyVoted(bytes32 _id, address _addr);
    error InsufficientVotingFee(uint256 _votingFee, uint256 _amountSent);



    modifier onlyOwner() {
        require(msg.sender==owner, "Only the Owner can call this function");
        _;
    }

    modifier onlyBettingContract() {
        require(msg.sender == bettingContract, "Only the assigned Betting Contract can call this function");
        _;
    }

    /// @notice assign the deployer as owner and deploy the betting contract associated with this oracle
    /// @notice The owner's power is limited only to add new matches or cancel matches that haven't started. The decision of outcome of a match occurs through decentralized voting.
    constructor() {
        owner = msg.sender;
        address addr = address(new SportsBetting());
        bettingContract = addr;
        emit BettingContractDeployed(addr);
    }

    /// @notice Can only be called by the owner. To transfer the ownership of owner to new owner( Owner's power is limited to only add new matches or cancel matches which have not yet started)
    /// @param newOwner the adress of the owner 
    function transferOwnership(address newOwner) external onlyOwner { 
        owner = newOwner;
    }
 
    /// @notice a private fuction which generates a psuedo random number by using last block parameters and hashing it.
    /// @return a pseudo random unsigned integer
    function random() private returns (uint) {
        randomCounter++;
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, randomCounter)));
    }

    /// @notice To get details(like current status, voting fee for the match of the match by its match id.
    /// @param matchId The id of the match whose details are needed.
    /// @return team1 The name of first team.
    /// @return team2 The name of second team.
    /// @return startTime The startTime of the match.
    /// @return endTime The endTime of the match.
    /// @return votingEndTime The time upto which voting for the result of the match can be done.
    /// @return status The status of the match (Pending,Started,Voting,Decided,Cancelled).
    /// @return result The result of the match that is decided upon. 
    function getMatchById(bytes32 matchId) external view returns(string memory team1, string memory team2,uint256 startTime, 
        uint256 endTime, uint256 votingEndTime, MatchStatus status, Result result) {
        Match memory m = matchesList[matchIdtoIndexMap[matchId]-1];
        return  (m.team1, m.team2, m.startTime, m.endTime, m.votingEndTime, m.status, m.result);
    }

    /// @notice To get Ids of all the matches.
    /// @return matchIds A list of all matchids
    function getAllMatchesIds() external view returns(bytes32[] memory matchIds) {
        matchIds = new bytes32[](matchesList.length);
        for(uint i=0;i<matchesList.length; i++)
        {
            matchIds[i]=matchesList[i].id ;
        }
    }


    
    /// @notice Add a new Match to the Oracle. Can only be done by the owner. (Oracle also syncs this info to Sports Betting Contract)
    /// @param _team1 The name of first team.
    /// @param _team2 The name if second team.
    /// @param _startTime The starting time for the match.
    /// @param _endTime The ending time for the match.
    /// @return newMatchId returns the unique id of the new match that got added. 
    function addNewMatch(string calldata _team1, string calldata _team2, uint256 _startTime, uint256 _endTime) 
      external onlyOwner returns(bytes32 newMatchId) {
        bytes32 id = keccak256(abi.encodePacked(_team1, _team2, _startTime, _endTime));
        
        require(_startTime <= _endTime , "Start time of the match has to be less than end time");
        require(matchIdtoIndexMap[id] == 0, "Match already Added");

        Match memory newMatch;
        newMatch.id = id;
        (newMatch.team1 , newMatch.team2) = (_team1 , _team2);
        (newMatch.startTime , newMatch.endTime) = (_startTime , _endTime);

        matchesList.push(newMatch);

        matchIdtoIndexMap[id] = matchesList.length;
        
        SportsBettingInterface(bettingContract).openBettingForMatch(id, _team1, _team2,_startTime, _endTime);

        emit NewMatchAdded(id , _team1, _team2, _startTime, _endTime);
        newMatchId = id;
    }

    /// @notice To Cancel A Match that was previously added. The match can be cancelled only if it hasnt started yet and is still in Pending phase. Can only be cancelled by the owner. Cancelled Match's result is assigned as NoResult.
    /// @param _id The id of the match which has to be cancelled.
    function cancelMatch(bytes32 _id) external onlyOwner {
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");

        Match storage _match = matchesList[matchIdtoIndexMap[_id]-1 ] ;
        
        if(_match.status == MatchStatus.Cancelled)
            revert MatchAlreadyCancelled(_id);

        require(_match.status==MatchStatus.Pending && _match.startTime > block.timestamp, "Can't Cancel already started Match");

        _match.status = MatchStatus.Cancelled;
        emit MatchCancelled(_match.id, _match.team1, _match.team2);

        SportsBettingInterface(bettingContract).concludeBettingForMatch(_id, Result.NoResult);
    }

    /// @notice To update the status of the match as started. Oracle checks that the requirements like current time is greater thatn startime are updated. Anyone can call this function. This function is to just update the state of Oracle to match the real world state of the match.
    /// @param _id The match whose status is to be updated to started. 
    function startMatch(bytes32 _id) external {
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");
        Match storage _match = matchesList[matchIdtoIndexMap[_id]-1] ;

        if(_match.status == MatchStatus.Started)
            revert MatchAlreadyStarted(_id);

        require(_match.status==MatchStatus.Pending && _match.startTime <= block.timestamp, "Can't start this match yet or the match was cancelled");

        _match.status = MatchStatus.Started;
        emit MatchStarted(_match.id, _match.team1, _match.team2);

        SportsBettingInterface(bettingContract).haltBettingForMatch(_id);
    } 
     

    /// @notice To update the status of the match as Ended. Oracle also starts the voting for the result of the match once the match has ended and announces the parameters for associated proof of work that voters need to do to sumbit thier votes.
    /// @param _id The match whose status is to be updated to ended/Voting and thr voting is to be starte.
    function endMatch(bytes32 _id) external {
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");
        Match storage _match = matchesList[matchIdtoIndexMap[_id]-1] ;
        
        if(_match.status == MatchStatus.Cancelled)
            revert MatchAlreadyCancelled(_id);
        if(_match.status == MatchStatus.Voting || _match.status == MatchStatus.Decided)
            revert MatchAlreadyEnded(_id);

        require(_match.status==MatchStatus.Started && _match.endTime <= block.timestamp, "Can't End the Match as of yet");

        _match.status = MatchStatus.Voting;
    
        emit MatchEnded(_match.id, _match.team1, _match.team2) ;

        uint256 randomNumber = random();
        
        bytes32 challenge = keccak256(abi.encodePacked(_match.id, randomNumber));
        uint256 votingFee = calculateVotingFee(_match.id);
        uint256 votingEndTime = calculateVotingEndTime(_match.id);
        uint256 difficulty = calculateDifficulty(_match.id);


        ChallengeParameters memory endedMatchChallengeParameters ;
        endedMatchChallengeParameters.matchChallenge = challenge;
        endedMatchChallengeParameters.votingFee = votingFee;
        endedMatchChallengeParameters.votingEndTime = votingEndTime;
        endedMatchChallengeParameters.difficulty = difficulty;

        matchChallengeParameters[_match.id] = endedMatchChallengeParameters;
        _match.votingEndTime = block.timestamp + votingEndTime;

        emit MatchChallengeAnnouncement(_match.id, challenge, difficulty, votingFee, block.timestamp + votingEndTime);

    }

    /// @notice To wake up the Oracle to release the decision/result of a match whose voting is over. This calls the Conclude betting function of Sports Betting Contract.
    /// @param _id The id of the match whose result is to be decided.
    function decideMatch(bytes32 _id) external {
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");

        Match storage _match = matchesList[matchIdtoIndexMap[_id]-1] ;

        if(_match.status == MatchStatus.Decided)
            revert MatchAlreadyDecided(_id);

        require(_match.status == MatchStatus.Voting,"This Match is not in the Voting Phase"); 

        require(_match.votingEndTime <= block.timestamp,"Cannot Decide as the Voting Phase is not yet over");

        _match.status = MatchStatus.Decided ;

        uint[4] memory count; 
        Result result = Result.NoResult; 
        uint max = 0; 
        for(uint i=0; i<votes[_id].length; i++)
        {
            count[uint(votes[_id][i].vote)]++;
            if(count[uint(votes[_id][i].vote)] > max)
            {
                max = count[uint(votes[_id][i].vote)];
                result = votes[_id][i].vote;
            }
        }

        _match.result = result;
        emit MatchResultDecided(_id, _match.team1, _match.team2, result);

        SportsBettingInterface(bettingContract).concludeBettingForMatch(_id, result);

    }
    
    /// @notice Voters use this function to submit their Proof of Work and the corresponding vote for the outcome of a match.
    /// @param _id The id of the match for whom the vote is submitted.
    /// @param _nonce The nonce that acts as the proof-of-work.
    /// @param _vote The vote of the user for what was the outcome of the match.
    function voteResult(bytes32 _id, string calldata _nonce, Result _vote) external payable {
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");

        Match storage _match = matchesList[matchIdtoIndexMap[_id]-1] ;

        if(_match.status == MatchStatus.Decided)
            revert MatchAlreadyDecided(_id);
        
        require(_match.status == MatchStatus.Voting, "This Match is Not Yet in its Voting Period");

        if(_match.votingEndTime <= block.timestamp) 
        {
            revert("Voting Period is Over");
        }

        if(alreadyVoted[_id][msg.sender] == true )
            revert AlreadyVoted(_id, msg.sender) ;
 
        require(_vote == Result.Team1 || _vote == Result.Team2 || _vote == Result.Draw,
            "Invalid vote Provided for Match Result");

        uint256 votingFee = matchChallengeParameters[_id].votingFee;
        bytes32 challenge = matchChallengeParameters[_id].matchChallenge;
        uint256 difficulty = matchChallengeParameters[_id].difficulty;

        if(msg.value < votingFee)
            revert InsufficientVotingFee(votingFee, msg.value);

        bytes32 hash = sha256(abi.encodePacked(sha256(abi.encodePacked(keccak256(abi.encodePacked(challenge, msg.sender, _nonce))))));

        require(uint(hash) % difficulty == 0, "Nonce provided is Invalid") ;

        alreadyVoted[_id][msg.sender]=true;
        votes[_id].push(Vote(msg.sender, msg.value, _vote));

    }

    /// @notice This function can only be called by the Sports Betting Contract. It calls it when a betting for the match is concluded and sends a percentage of winnings back to the Oracle
    /// @notice The Oracle distributes the winnings to the voters who submitted the correct vote which incentivizes the voters to vote correctly.
    /// @param _id The id of the match for which the winnings have to be distributed.
    function distributeVoterWinnigs(bytes32 _id ) external payable override onlyBettingContract{
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");

        uint256 count_correctly_voted=0;
        Result result = matchesList[matchIdtoIndexMap[_id]-1].result;

        for(uint i=0; i<votes[_id].length; i++)
        {
            if(votes[_id][i].vote == result)
                count_correctly_voted++;
        }

        //TODO : Handle this case more properly, think of various other reasons this can happen
        if(count_correctly_voted == 0)
            return;


        // The winnings along with the previous votingFee/stake are sent back to the voters who had voted correctly.
        // Malacious voters who had voted incorrectly do not get thier votingFee back.
        //TODO : Right Now the ethers associated with votingFee of voters who have voted incorrectly remains in the contract usused. Think of what can be done about this. 
        for(uint i=0; i<votes[_id].length; i++)
        {
            if(votes[_id][i].vote == result)
            {
                uint256 amount = votes[_id][i].stake + (msg.value / count_correctly_voted) ;
                payable(votes[_id][i].voterAddress).transfer(amount);
            }    
        }

    }

    /// @notice private function which calculated the votingFee that voters will have to give for sumbitting their votes.
    /// @notice Right now the voting fee is calculated as a % of the total amount in betting pool of that match.  
    /// @param _id The id of the match.
    function calculateVotingFee(bytes32 _id) private returns(uint256){
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");

        uint256 amount = SportsBettingInterface(bettingContract).getTotalBettingPoolAmount(_id);

        return amount/10;
    }


    /// @notice private function which calcultes how much votingTime should be given to voters for voting for the outcome of this match.
    /// @notice Right now the voting time is set to default 5 minutes. Can modify it to more complex logic later like calculating based on how many voters submitted votes based on how much time for last match which was voted.
    /// @param _id The id of the match.
    function calculateVotingEndTime(bytes32 _id) private view returns(uint256){
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");
        return 5 minutes;
    }


    /// @notice private function which calcultes how much should be the difficulty for the proof of work for voting for the outcome of this match.
    /// @notice For trial purposes difficulty is kept as just 1 (any nonce will satisfy). Can modify it to more complex logic later like calculating based on how many voters submitted votes based on how much time for last match which was voted. 
    /// @param _id The id of the match.
    function calculateDifficulty(bytes32 _id) private view returns(uint256){
        require(matchIdtoIndexMap[_id] !=0 , "Invalid Match ID");
        return 1;
    }
} 