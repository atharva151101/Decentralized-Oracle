// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "./CommonTypes.sol";

/// @title interface used by SportsBetting Contract for calling some required functions of the Oracle Contract. Also Defines some required types for Oracle Contract.
interface OracleInterface {
    struct Match{
        bytes32 id;
        string team1;
        string team2;
        uint256 startTime;
        uint256 endTime;
        uint256 votingEndTime;
        MatchStatus status;
        Result result;
    }

    enum MatchStatus{ 
        Pending,
        Started,
        Voting,
        Decided,
        Cancelled
    }

    struct ChallengeParameters {
        bytes32 matchChallenge;
        uint256 votingFee;
        uint256 votingEndTime;
        uint256 difficulty;
    }

    struct Vote {
        address voterAddress;
        uint256 stake;
        Result vote;
    }

    function distributeVoterWinnigs(bytes32 _id) external payable;

} 