// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "./CommonTypes.sol";

/// @title interface used by Oracle for calling some required only Oracle functions of the Sports Betting Contract. Also defines some types required for Sports Betting Contract.
interface SportsBettingInterface{
    enum MatchBettingStatus{
        Ongoing,
        Halted,
        Concluded
    }

    struct MatchBettingInstance{
        bytes32 matchId;
        string team1;
        string team2;
        uint256 matchStartTime;
        uint256 matchEndTime;
        MatchBettingStatus bettingStatus;
        Result result;
    }

    struct Bet{
        address betterAddress;
        uint256 team1_amount;
        uint256 team2_amount;
        uint256 draw_amount;
    }

    function openBettingForMatch( bytes32 _id, string calldata _team1, string calldata _team2, uint256 _startTime, uint256 _endTime) external;

    function haltBettingForMatch(bytes32 _id) external ;

    function concludeBettingForMatch(bytes32 _id, Result _result) external;

    function getTotalBettingPoolAmount(bytes32 _matchId) external returns(uint256); 
}

