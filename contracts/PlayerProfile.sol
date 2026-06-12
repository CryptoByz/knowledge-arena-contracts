// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PlayerProfile is Ownable {

    struct Profile {
        uint256 totalScore;
        uint256 weeklyScore;
        uint256 monthlyScore;
        uint256 seasonScore;
        uint256 streakDays;
        uint256 lastPlayedTimestamp;
        uint256 boostMultiplier;  // 100 = 1.00x, 110 = 1.10x, 135 = 1.35x
        uint32  achievementFlags; // bit array, 32 achievement'a kadar
        bool    exists;
    }

    mapping(address => Profile) private profiles;
    address public quizContract;

    // Streak eşikleri ve boost değerleri
    uint256[4] public streakThresholds = [3, 7, 14, 30];
    uint256[4] public streakBoosts     = [105, 110, 120, 135];

    // Grace day: 1 gün kaçırırsan streak ölmez
    uint256 public constant GRACE_PERIOD = 48 hours;
    uint256 public constant DAY          = 24 hours;

    event ProfileCreated(address indexed player);
    event ScoreUpdated(address indexed player, uint256 rawScore, uint256 boostedScore);
    event StreakUpdated(address indexed player, uint256 streakDays, uint256 boostMultiplier);
    event PeriodReset(uint8 period);

    modifier onlyQuiz() {
        require(msg.sender == quizContract, "Only quiz contract");
        _;
    }

    constructor() Ownable() {}

    function setQuizContract(address _quiz) external onlyOwner {
        quizContract = _quiz;
    }

    // Quiz contract çağırır - skor + streak güncelle
    function recordPlay(address player, uint8 rawScore) external onlyQuiz {
        Profile storage p = profiles[player];

        if (!p.exists) {
            p.exists = true;
            p.boostMultiplier = 100;
            emit ProfileCreated(player);
        }

        // Streak güncelle
        _updateStreak(player);

        // Boost uygula
        uint256 boosted = (rawScore * p.boostMultiplier) / 100;

        // Skorları güncelle
        p.totalScore += boosted;
        _updateEpochScores(player, boosted);

        emit ScoreUpdated(player, rawScore, boosted);
    }

    function _updateStreak(address player) internal {
        Profile storage p = profiles[player];
        uint256 now_ = block.timestamp;

        if (p.lastPlayedTimestamp == 0) {
            // İlk oynama
            p.streakDays = 1;
        } else {
            uint256 elapsed = now_ - p.lastPlayedTimestamp;

            if (elapsed <= DAY + GRACE_PERIOD) {
                // Streak devam ediyor (grace day dahil)
                if (elapsed >= DAY) {
                    p.streakDays += 1;
                }
                // elapsed < DAY: aynı gün, streak değişmez (enterQuiz zaten engeller)
            } else {
                // Streak kırıldı
                p.streakDays = 1;
            }
        }

        p.lastPlayedTimestamp = now_;

        // Boost hesapla
        p.boostMultiplier = _calcBoost(p.streakDays);
        emit StreakUpdated(player, p.streakDays, p.boostMultiplier);
    }

    function _calcBoost(uint256 streak) internal view returns (uint256) {
        uint256 boost = 100;
        for (uint256 i = streakThresholds.length; i > 0; i--) {
            if (streak >= streakThresholds[i-1]) {
                boost = streakBoosts[i-1];
                break;
            }
        }
        return boost;
    }

    // Dönem sonu sıfırlama (owner çağırır)
    // 0 = weekly, 1 = monthly, 2 = season
    function resetPeriodScores(uint8 period) external onlyOwner {
        // Not: tüm oyuncuları döngüye sokmak gas açısından imkansız.
        // Bu yüzden "epoch" bazlı yaklaşım kullanıyoruz.
        // Skor okuma fonksiyonları epoch'a göre filtreler.
        // Gerçek reset yerine epoch counter artırılır.
        if (period == 0) weeklyEpoch++;
        else if (period == 1) monthlyEpoch++;
        else seasonEpoch++;
        emit PeriodReset(period);
    }

    // Epoch counter'lar - dönem bazlı skor takibi için
    uint256 public weeklyEpoch;
    uint256 public monthlyEpoch;
    uint256 public seasonEpoch;

    // Dönem başlangıcından bu yana skor
    mapping(address => mapping(uint256 => uint256)) public weeklyScoreByEpoch;
    mapping(address => mapping(uint256 => uint256)) public monthlyScoreByEpoch;
    mapping(address => mapping(uint256 => uint256)) public seasonScoreByEpoch;

    // Okuma fonksiyonları
    function getProfile(address player) external view returns (
        uint256 totalScore,
        uint256 weeklyScore,
        uint256 monthlyScore,
        uint256 seasonScore,
        uint256 streakDays,
        uint256 boostMultiplier,
        uint32  achievementFlags
    ) {
        Profile storage p = profiles[player];
        return (
            p.totalScore,
            weeklyScoreByEpoch[player][weeklyEpoch],
            monthlyScoreByEpoch[player][monthlyEpoch],
            seasonScoreByEpoch[player][seasonEpoch],
            p.streakDays,
            p.boostMultiplier,
            p.achievementFlags
        );
    }

    function setAchievementFlag(address player, uint8 flagIndex) external onlyQuiz {
        profiles[player].achievementFlags |= uint32(1 << flagIndex);
    }

    function hasAchievement(address player, uint8 flagIndex) external view returns (bool) {
        return (profiles[player].achievementFlags & uint32(1 << flagIndex)) != 0;
    }

    // recordPlay'de epoch bazlı skorları da güncelle
    // (yukarıdaki recordPlay'e ek olarak bu internal fonksiyon çağrılır)
    function _updateEpochScores(address player, uint256 boosted) internal {
        weeklyScoreByEpoch[player][weeklyEpoch]   += boosted;
        monthlyScoreByEpoch[player][monthlyEpoch] += boosted;
        seasonScoreByEpoch[player][seasonEpoch]   += boosted;
    }
}
