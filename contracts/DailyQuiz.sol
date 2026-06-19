// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./PlayerProfile.sol";
import "./AchievementManager.sol";

contract DailyQuiz is Ownable {

    PlayerProfile      public playerProfile;
    AchievementManager public achievementManager;

    uint256 public constant QUESTIONS_PER_DAY = 10;

    mapping(uint256 => bytes32) public dailyMerkleRoot;
    mapping(address => uint256) public lastPlayedDay;
    mapping(address => mapping(uint256 => bool))  public hasSubmitted;
    mapping(address => mapping(uint256 => uint8)) public dailyScore;

    uint256 public totalGamesPlayed;

    event QuizEntered(address indexed player, uint256 dayIndex);
    event QuizCompleted(address indexed player, uint256 dayIndex, uint8 score, uint256 boostedScore);
    event MerkleRootSet(uint256 dayIndex, bytes32 root);

    constructor(
        address _playerProfile,
        address _achievementManager
    ) Ownable() {
        playerProfile      = PlayerProfile(_playerProfile);
        achievementManager = AchievementManager(_achievementManager);
    }

    function todayIndex() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function setDailyMerkleRoot(bytes32 root, uint256 dayIndex) external onlyOwner {
        require(dailyMerkleRoot[dayIndex] == bytes32(0), "Root already set");
        dailyMerkleRoot[dayIndex] = root;
        emit MerkleRootSet(dayIndex, root);
    }

    function enterQuiz() external {
        uint256 today = todayIndex();
        require(dailyMerkleRoot[today] != bytes32(0), "Quiz not initialized yet");
        require(lastPlayedDay[msg.sender] < today, "Already entered today");
        lastPlayedDay[msg.sender] = today;
        emit QuizEntered(msg.sender, today);
    }

    function submitAnswers(
        bytes32[] calldata answerHashes,
        bytes32[][] calldata proofs
    ) external {
        uint256 today = todayIndex();
        require(lastPlayedDay[msg.sender] == today, "Not entered today");
        require(!hasSubmitted[msg.sender][today], "Already submitted");
        require(answerHashes.length == QUESTIONS_PER_DAY, "Wrong answer count");
        require(proofs.length == QUESTIONS_PER_DAY, "Wrong proof count");

        bytes32 root = dailyMerkleRoot[today];
        uint8 score = 0;

        for (uint256 i = 0; i < QUESTIONS_PER_DAY; i++) {
            if (MerkleProof.verify(proofs[i], root, answerHashes[i])) {
                score++;
            }
        }

        hasSubmitted[msg.sender][today] = true;
        dailyScore[msg.sender][today]   = score;
        totalGamesPlayed++;

        playerProfile.recordPlay(msg.sender, score);
        achievementManager.checkAchievements(msg.sender, score);

        (,,,,, uint256 boost,) = playerProfile.getProfile(msg.sender);
        uint256 boosted = (uint256(score) * boost) / 100;

        emit QuizCompleted(msg.sender, today, score, boosted);
    }

    function isTodayReady() external view returns (bool) {
        return dailyMerkleRoot[todayIndex()] != bytes32(0);
    }

    function canPlay(address player) external view returns (bool) {
        return lastPlayedDay[player] < todayIndex();
    }

    function getTodayScore(address player) external view returns (uint8, bool) {
        uint256 today = todayIndex();
        return (dailyScore[player][today], hasSubmitted[player][today]);
    }
}
