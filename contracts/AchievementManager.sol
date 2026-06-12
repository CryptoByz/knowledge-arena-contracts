// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PlayerProfile.sol";
import "./BadgeNFT.sol";

contract AchievementManager is Ownable {

    PlayerProfile public playerProfile;
    BadgeNFT      public badgeNFT;
    address       public quizContract;

    struct Achievement {
        string  name;
        string  description;
        uint8   flagIndex;       // PlayerProfile bit pozisyonu
        uint256 badgeTokenId;    // BadgeNFT token ID (3'ten başlar)
        // Kriter türü ve eşiği
        CriteriaType criteriaType;
        uint256 criteriaValue;
    }

    enum CriteriaType {
        TOTAL_SCORE,    // toplam skor eşiği
        STREAK_DAYS,    // streak gün eşiği
        GAMES_PLAYED,   // toplam oyun sayısı
        PERFECT_SCORE   // 10/10 alan oyun sayısı
    }

    Achievement[] public achievements;

    // Oyuncu istatistikleri (quiz contract günceller)
    mapping(address => uint256) public gamesPlayed;
    mapping(address => uint256) public perfectGames;

    event AchievementAdded(uint8 flagIndex, string name);
    event AchievementUnlocked(address indexed player, uint8 flagIndex, string name);

    modifier onlyQuiz() {
        require(msg.sender == quizContract, "Only quiz contract");
        _;
    }

    constructor(address _playerProfile, address _badgeNFT) Ownable() {
        playerProfile = PlayerProfile(_playerProfile);
        badgeNFT      = BadgeNFT(_badgeNFT);
        _initAchievements();
    }

    function setQuizContract(address _quiz) external onlyOwner {
        quizContract = _quiz;
    }

    // Başlangıç achievement'ları
    function _initAchievements() internal {
    _addAchievement("First Step",       "Complete your first quiz",    0, 3,  CriteriaType.GAMES_PLAYED,  1);
    _addAchievement("Week Warrior",     "7 day streak",                1, 4,  CriteriaType.STREAK_DAYS,   7);
    _addAchievement("Month Master",     "30 day streak",               2, 5,  CriteriaType.STREAK_DAYS,   30);
    _addAchievement("Knowledge Seeker", "Earn 100 total score",        3, 6,  CriteriaType.TOTAL_SCORE,   100);
    _addAchievement("Expert",           "Earn 1000 total score",       4, 7,  CriteriaType.TOTAL_SCORE,   1000);
    _addAchievement("Perfectionist",    "First perfect score (10/10)", 5, 8,  CriteriaType.PERFECT_SCORE, 1);
    _addAchievement("Flawless",         "5 perfect scores",            6, 9,  CriteriaType.PERFECT_SCORE, 5);
    _addAchievement("Veteran",          "Complete 50 quizzes",         7, 10, CriteriaType.GAMES_PLAYED,  50);
}
    function _addAchievement(
        string memory name,
        string memory desc,
        uint8 flagIndex,
        uint256 tokenId,
        CriteriaType cType,
        uint256 cValue
    ) internal {
        achievements.push(Achievement(name, desc, flagIndex, tokenId, cType, cValue));
        emit AchievementAdded(flagIndex, name);
    }

    // Quiz contract her oyun sonunda çağırır
    function checkAchievements(address player, uint8 score) external onlyQuiz {
        gamesPlayed[player]++;
        if (score == 10) perfectGames[player]++;

        (uint256 totalScore,,,,uint256 streakDays,,uint32 currentFlags) =
            playerProfile.getProfile(player);

        for (uint256 i = 0; i < achievements.length; i++) {
            Achievement storage ach = achievements[i];

            // Zaten unlock edildi mi?
            if ((currentFlags & uint32(1 << ach.flagIndex)) != 0) continue;

            bool unlocked = false;

            if (ach.criteriaType == CriteriaType.TOTAL_SCORE) {
                unlocked = totalScore >= ach.criteriaValue;
            } else if (ach.criteriaType == CriteriaType.STREAK_DAYS) {
                unlocked = streakDays >= ach.criteriaValue;
            } else if (ach.criteriaType == CriteriaType.GAMES_PLAYED) {
                unlocked = gamesPlayed[player] >= ach.criteriaValue;
            } else if (ach.criteriaType == CriteriaType.PERFECT_SCORE) {
                unlocked = perfectGames[player] >= ach.criteriaValue;
            }

            if (unlocked) {
                playerProfile.setAchievementFlag(player, ach.flagIndex);
                emit AchievementUnlocked(player, ach.flagIndex, ach.name);
            }
        }
    }

    // Kullanıcı unlock ettiği achievement'ın NFT'sini mint eder
    function mintAchievementBadge(uint8 achievementIndex) external {
        require(achievementIndex < achievements.length, "Invalid index");
        Achievement storage ach = achievements[achievementIndex];

        require(
            playerProfile.hasAchievement(msg.sender, ach.flagIndex),
            "Achievement not unlocked"
        );
        require(
            !badgeNFT.minted(msg.sender, ach.badgeTokenId),
            "Already minted"
        );

        badgeNFT.mint(msg.sender, ach.badgeTokenId);
    }

    // Tüm achievement'ları döndür (frontend için)
    function getAllAchievements() external view returns (Achievement[] memory) {
        return achievements;
    }

    // Oyuncunun achievement durumunu döndür
    function getPlayerAchievements(address player) external view returns (
        bool[] memory unlocked,
        bool[] memory minted_
    ) {
        unlocked = new bool[](achievements.length);
        minted_  = new bool[](achievements.length);

        for (uint256 i = 0; i < achievements.length; i++) {
            unlocked[i] = playerProfile.hasAchievement(player, achievements[i].flagIndex);
            minted_[i]  = badgeNFT.minted(player, achievements[i].badgeTokenId);
        }
    }

    // Owner yeni achievement ekleyebilir
    function addAchievement(
        string memory name,
        string memory desc,
        uint8 flagIndex,
        uint256 tokenId,
        CriteriaType cType,
        uint256 cValue
    ) external onlyOwner {
        _addAchievement(name, desc, flagIndex, tokenId, cType, cValue);
    }
}
