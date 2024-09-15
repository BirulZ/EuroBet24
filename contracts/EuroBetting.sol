// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EuroBetToken.sol";


contract EuroBetting {
EuroBetToken public euroBetToken;
   address payable public owner;

   struct Match {
        string team1;
        string team2;
        uint256 team1Pot;
        uint256 team2Pot;
        bool isOpen;
        bool isFinished;
        string winner;
   }
    mapping(uint256 => Match) public matches; // Struct um Matches zu definieren
    mapping(uint256 => mapping(address => mapping(string => uint256))) public bets; // Match ids zu structs
    uint256 public matchCount; //anzahl von Matches, damit man jederzeit schauen kann welche Matches hinterlegt sind

    //Events and trigger
    event MatchCreated(uint256 matchId, string team1, string team2);
    //event BetPlaced(uint256 matchId, address bettor, string team, uint256 amount);
    event MatchFinished(uint256 matchId, string winner);
    event WinningsClaimed(uint256 matchId, address bettor, uint256 amount);

    event BetPlaced(uint256 indexed matchId, address indexed bettor, string team, uint256 amount);
    event DebugLog(string message, uint256 value);

    constructor(address _euroBetTokenAddress)  {
        euroBetToken = EuroBetToken(_euroBetTokenAddress);
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function createMatch(string memory _team1, string memory _team2) external onlyOwner {
        matchCount++;
        matches[matchCount] = Match(_team1, _team2, 0, 0, true, false, "");
        emit MatchCreated(matchCount, _team1, _team2);
    }

    function placeBet(uint256 _matchId, string memory _team, uint256 _amount) public payable {
        emit DebugLog("Function started", _matchId);
        
        require(_matchId > 0 && _matchId <= matchCount, "Invalid match ID");
        emit DebugLog("Match ID valid", _matchId);
        
        require(matches[_matchId].isOpen, "Match is not open for betting");
        emit DebugLog("Match is open", 0);
        
        require(_amount > 0, "Bet amount must be greater than 0");
        emit DebugLog("Amount is valid", _amount);
        
        require(bytes(_team).length > 0, "Team name cannot be empty");
        emit DebugLog("Team name is not empty", 0);
        
        Match storage newMatch = matches[_matchId];
        require(
            keccak256(abi.encodePacked(_team)) == keccak256(abi.encodePacked(newMatch.team1)) ||
            keccak256(abi.encodePacked(_team)) == keccak256(abi.encodePacked(newMatch.team2)),
            "Invalid team name"
        );
        emit DebugLog("Team name is valid", 0);

        uint256 userBalance = euroBetToken.balanceOf(msg.sender);
        require(userBalance >= _amount, "Insufficient balance");
        emit DebugLog("User has sufficient balance", userBalance); 

        uint256 userAllowance = euroBetToken.allowance(msg.sender, address(this));
        require(userAllowance >= _amount, "Insufficient allowance");
        emit DebugLog("User has sufficient allowance", userAllowance);   

        bool transferSuccess = euroBetToken.transferForBetting(msg.sender, address(this), _amount);
        require(transferSuccess, "Token transfer failed");
        emit DebugLog("Token transfer successful", _amount); 

        
        if (keccak256(abi.encodePacked(_team)) == keccak256(abi.encodePacked(newMatch.team1))) {
            newMatch.team1Pot += _amount;
        } else {
            newMatch.team2Pot += _amount;
        }

        bets[_matchId][msg.sender][_team] += _amount;
        emit BetPlaced(_matchId, msg.sender, _team, _amount);
        emit DebugLog("Bet placed successfully", _amount);
    }

    function finishMatch(uint256 _matchId, string memory _winner) external onlyOwner {
        require(!matches[_matchId].isFinished, "Match is already finished");
        require(keccak256(abi.encodePacked(_winner)) == keccak256(abi.encodePacked(matches[_matchId].team1)) ||
                keccak256(abi.encodePacked(_winner)) == keccak256(abi.encodePacked(matches[_matchId].team2)),
                "Invalid winner");

        matches[_matchId].isOpen = false;
        matches[_matchId].isFinished = true;
        matches[_matchId].winner = _winner;

        emit MatchFinished(_matchId, _winner);
    }

    function claimWinnings(uint256 _matchId) external payable {
        require(matches[_matchId].isFinished, "Match is not finished yet");
        string memory winner = matches[_matchId].winner;
        uint256 betAmount = bets[_matchId][msg.sender][winner];
        require(betAmount > 0, "No winning bet found");

        uint256 totalPot = matches[_matchId].team1Pot + matches[_matchId].team2Pot;
        uint256 winningPot = keccak256(abi.encodePacked(winner)) == keccak256(abi.encodePacked(matches[_matchId].team1)) ?
            matches[_matchId].team1Pot : matches[_matchId].team2Pot;

        uint256 winnings = (betAmount * totalPot) / winningPot; //Berrechnung der AUsschüttung
        bets[_matchId][msg.sender][winner] = 0;

        require(euroBetToken.transfer(msg.sender, winnings), "Token transfer failed");
        emit WinningsClaimed(_matchId, msg.sender, winnings);
    }
    function getOpenMatches() external view returns (uint256[] memory, string[] memory, string[] memory) {
        uint256 openMatchCount = 0;
        
        //  Anzahl der offene Spiele
        for (uint256 i = 1; i <= matchCount; i++) {
            if (matches[i].isOpen) {
                openMatchCount++;
            }
        }
        
        //  Arrays für  Rückgabewerte
        uint256[] memory matchIds = new uint256[](openMatchCount);
        string[] memory team1Names = new string[](openMatchCount);
        string[] memory team2Names = new string[](openMatchCount);
        
        //  Arrays mit den Daten der offenen Spiele
        uint256 currentIndex = 0;
        for (uint256 i = 1; i <= matchCount; i++) {
            if (matches[i].isOpen) {
                matchIds[currentIndex] = i;
                team1Names[currentIndex] = matches[i].team1;
                team2Names[currentIndex] = matches[i].team2;
                currentIndex++;
            }
        }
        
        return (matchIds, team1Names, team2Names);
    }
    
}
