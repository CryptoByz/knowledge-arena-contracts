// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ChallengeQuiz is Ownable {

    struct Challenge {
        bytes32 merkleRoot;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 questionsCount;
        bool isActive;
    }

    // mapping challengeId => Challenge
    mapping(string => Challenge) public challenges;
    
    // mapping player => challengeId => hasPlayed
    mapping(address => mapping(string => bool)) public hasPlayed;
    
    // mapping player => challengeId => score
    mapping(address => mapping(string => uint8)) public challengeScores;

    event ChallengeRegistered(string challengeId, bytes32 merkleRoot, uint256 startTimestamp, uint256 endTimestamp, uint256 questionsCount);
    event ChallengeQuizEntered(address indexed player, string challengeId);
    event ChallengeQuizCompleted(address indexed player, string challengeId, uint8 score, uint256 timestamp);

    constructor() Ownable() {}

    function registerChallenge(
        string calldata challengeId,
        bytes32 merkleRoot,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 questionsCount
    ) external onlyOwner {
        challenges[challengeId] = Challenge({
            merkleRoot: merkleRoot,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            questionsCount: questionsCount,
            isActive: true
        });
        emit ChallengeRegistered(challengeId, merkleRoot, startTimestamp, endTimestamp, questionsCount);
    }

    function toggleChallengeActive(string calldata challengeId, bool active) external onlyOwner {
        challenges[challengeId].isActive = active;
    }

    function enterChallenge(string calldata challengeId) external {
        Challenge memory c = challenges[challengeId];
        require(c.isActive, "Challenge not active");
        require(block.timestamp >= c.startTimestamp, "Challenge not started yet");
        require(block.timestamp <= c.endTimestamp, "Challenge already ended");
        require(!hasPlayed[msg.sender][challengeId], "Already played this challenge");

        emit ChallengeQuizEntered(msg.sender, challengeId);
    }

    function submitChallengeAnswers(
        string calldata challengeId,
        bytes32[] calldata answerHashes,
        bytes32[][] calldata proofs
    ) external {
        Challenge memory c = challenges[challengeId];
        require(c.isActive, "Challenge not active");
        require(block.timestamp >= c.startTimestamp, "Challenge not started yet");
        require(block.timestamp <= c.endTimestamp, "Challenge already ended");
        require(!hasPlayed[msg.sender][challengeId], "Already played this challenge");
        require(answerHashes.length == c.questionsCount, "Wrong answer count");
        require(proofs.length == c.questionsCount, "Wrong proof count");

        bytes32 root = c.merkleRoot;
        uint8 score = 0;

        for (uint256 i = 0; i < c.questionsCount; i++) {
            if (MerkleProof.verify(proofs[i], root, answerHashes[i])) {
                score++;
            }
        }

        hasPlayed[msg.sender][challengeId] = true;
        challengeScores[msg.sender][challengeId] = score;

        emit ChallengeQuizCompleted(msg.sender, challengeId, score, block.timestamp);
    }

    function getChallengeStatus(string calldata challengeId, address player) external view returns (
        bool isActive,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 questionsCount,
        bool played,
        uint8 score
    ) {
        Challenge memory c = challenges[challengeId];
        return (
            c.isActive,
            c.startTimestamp,
            c.endTimestamp,
            c.questionsCount,
            hasPlayed[player][challengeId],
            challengeScores[player][challengeId]
        );
    }
}
