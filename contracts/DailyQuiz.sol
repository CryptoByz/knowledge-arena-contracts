// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PlayerProfile.sol";
import "./RewardPool.sol";
import "./AchievementManager.sol";

contract DailyQuiz is Ownable {

    IERC20           public usdc;
    PlayerProfile    public playerProfile;
    RewardPool       public rewardPool;
    AchievementManager public achievementManager;

    uint256 public entryFee = 10 * 10**6; // 10 USDC (6 decimal)
    uint256 public constant QUESTIONS_PER_DAY = 10;

    // Günlük merkle root: dayIndex → root
    mapping(uint256 => bytes32) public dailyMerkleRoot;

    // Oyuncu günlük durumu
    mapping(address => uint256) public lastPlayedDay;
    mapping(address => mapping(uint256 => bool)) public hasSubmitted;
    mapping(address => mapping(uint256 => uint8)) public dailyScore;

    // Toplam oyun sayısı (leaderboard için)
    uint256 public totalGamesPlayed;

    event QuizEntered(address indexed player, uint256 dayIndex, uint256 fee);
    event QuizCompleted(address indexed player, uint256 dayIndex, uint8 score, uint256 boostedScore);
    event MerkleRootSet(uint256 dayIndex, bytes32 root);
    event EntryFeeUpdated(uint256 newFee);

    constructor(
        address _usdc,
        address _playerProfile,
        address _rewardPool,
        address _achievementManager
    ) Ownable() {
        usdc               = IERC20(_usdc);
        playerProfile      = PlayerProfile(_playerProfile);
        rewardPool         = RewardPool(_rewardPool);
        achievementManager = AchievementManager(_achievementManager);
    }

    // Günün index'i (her gün 00:00 UTC'de artar)
    function todayIndex() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    // RPi5 her sabah 00:00 UTC'de bu fonksiyonu çağırır
    function setDailyMerkleRoot(bytes32 root, uint256 dayIndex) external onlyOwner {
        require(dailyMerkleRoot[dayIndex] == bytes32(0), "Root already set");
        dailyMerkleRoot[dayIndex] = root;
        emit MerkleRootSet(dayIndex, root);
    }

    // Adım 1: Quiz'e giriş (10 USDC öde)
    function enterQuiz() external {
        uint256 today = todayIndex();

        require(dailyMerkleRoot[today] != bytes32(0), "Quiz not initialized yet");
        require(lastPlayedDay[msg.sender] < today, "Already entered today");

        // USDC transfer (kullanıcı önceden approve etmeli)
        require(
            usdc.transferFrom(msg.sender, address(rewardPool), entryFee),
            "USDC transfer failed"
        );

        // RewardPool'a fee bildir
        rewardPool.receiveFee(entryFee);

        lastPlayedDay[msg.sender] = today;

        emit QuizEntered(msg.sender, today, entryFee);
    }

    // Adım 2: Cevapları gönder
    // answers: her soru için seçilen şık (keccak256 hash'i)
    // proofs: her cevap için RPi5'ten alınan merkle proof
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
            // Merkle proof doğrula
            bool valid = MerkleProof.verify(proofs[i], root, answerHashes[i]);
            if (valid) score++;
        }

        hasSubmitted[msg.sender][today] = true;
        dailyScore[msg.sender][today]   = score;
        totalGamesPlayed++;

        // PlayerProfile güncelle (skor + streak + boost)
        playerProfile.recordPlay(msg.sender, score);

        // Achievement kontrol et
        achievementManager.checkAchievements(msg.sender, score);

        // Boosted skoru event'te emit et
        (uint256 totalScore,,,,, uint256 boost,) = playerProfile.getProfile(msg.sender);
        uint256 boosted = (score * boost) / 100;

        emit QuizCompleted(msg.sender, today, score, boosted);
    }

    // Entry fee güncelle (owner)
    function setEntryFee(uint256 newFee) external onlyOwner {
        entryFee = newFee;
        emit EntryFeeUpdated(newFee);
    }

    // Bugünkü quiz hazır mı?
    function isTodayReady() external view returns (bool) {
        return dailyMerkleRoot[todayIndex()] != bytes32(0);
    }

    // Oyuncunun bugün oynayıp oynamadığı
    function canPlay(address player) external view returns (bool) {
        return lastPlayedDay[player] < todayIndex();
    }

    // Oyuncunun bugünkü skoru (oynadıysa)
    function getTodayScore(address player) external view returns (uint8, bool) {
        uint256 today = todayIndex();
        return (dailyScore[player][today], hasSubmitted[player][today]);
    }
}
