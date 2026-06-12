// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BadgeNFT.sol";

contract RewardPool is Ownable {

    IERC20  public usdc;
    BadgeNFT public badgeNFT;

    address public quizContract;
    address public platform;       // platform payı gidecek adres

    // Fee dağılım oranları (toplam 100)
    uint256 public constant REWARD_SHARE   = 70;
    uint256 public constant PLATFORM_SHARE = 20;
    uint256 public constant ACHIEVE_SHARE  = 10;

    // Pool bakiyeleri
    uint256 public weeklyPool;
    uint256 public monthlyPool;
    uint256 public seasonPool;
    uint256 public achievementPool;

    // Her dönem pool'a ne kadar gittiği (birikimli)
    // weekly:monthly:season → 50:30:20 oranında bölünür
    uint256 public constant WEEKLY_SPLIT  = 50;
    uint256 public constant MONTHLY_SPLIT = 30;
    uint256 public constant SEASON_SPLIT  = 20;

    // Claim edilebilir bakiyeler
    mapping(address => uint256) public claimableUSDC;

    // NFT claim hakları: adres → tokenId → claim edebilir mi
    mapping(address => mapping(uint256 => bool)) public claimableNFT;

    event FeeReceived(uint256 amount, uint256 toReward, uint256 toPlatform, uint256 toAchieve);
    event RewardsDistributed(uint8 period, address[] winners, uint256[] amounts);
    event NFTRewardSet(address indexed player, uint256 tokenId);
    event Claimed(address indexed player, uint256 usdcAmount);
    event NFTClaimed(address indexed player, uint256 tokenId);

    modifier onlyQuiz() {
        require(msg.sender == quizContract, "Only quiz contract");
        _;
    }

    constructor(address _usdc, address _badgeNFT, address _platform) Ownable() {
        usdc        = IERC20(_usdc);
        badgeNFT    = BadgeNFT(_badgeNFT);
        platform    = _platform;
    }

    function setQuizContract(address _quiz) external onlyOwner {
        quizContract = _quiz;
    }

    // DailyQuiz.sol tarafından her entry'de çağrılır
    function receiveFee(uint256 amount) external onlyQuiz {
        uint256 toReward   = (amount * REWARD_SHARE)   / 100;
        uint256 toPlatform = (amount * PLATFORM_SHARE) / 100;
        uint256 toAchieve  = amount - toReward - toPlatform;

        // Reward payını dönemlere böl
        weeklyPool  += (toReward * WEEKLY_SPLIT)  / 100;
        monthlyPool += (toReward * MONTHLY_SPLIT) / 100;
        seasonPool  += (toReward * SEASON_SPLIT)  / 100;

        achievementPool += toAchieve;

        // Platform payını direkt gönder
        require(usdc.transfer(platform, toPlatform), "Platform transfer failed");

        emit FeeReceived(amount, toReward, toPlatform, toAchieve);
    }

    // Dönem sonu: owner leaderboard snapshot'a göre çağırır
    // period: 0=weekly, 1=monthly, 2=season
    function distributeRewards(
        uint8 period,
        address[] calldata winners,
        uint256[] calldata amounts,
        uint256[] calldata nftTokenIds  // her kazanana hangi NFT
    ) external onlyOwner {
        require(winners.length == amounts.length, "Length mismatch");
        require(winners.length == nftTokenIds.length, "Length mismatch");

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        // Pool yeterliliği kontrol
        if (period == 0) {
            require(weeklyPool >= totalAmount, "Insufficient weekly pool");
            weeklyPool -= totalAmount;
        } else if (period == 1) {
            require(monthlyPool >= totalAmount, "Insufficient monthly pool");
            monthlyPool -= totalAmount;
        } else {
            require(seasonPool >= totalAmount, "Insufficient season pool");
            seasonPool -= totalAmount;
        }

        // Claimable mapping'e yaz
        for (uint256 i = 0; i < winners.length; i++) {
            claimableUSDC[winners[i]]               += amounts[i];
            claimableNFT[winners[i]][nftTokenIds[i]] = true;
            emit NFTRewardSet(winners[i], nftTokenIds[i]);
        }

        emit RewardsDistributed(period, winners, amounts);
    }

    // Kullanıcı USDC claim eder
    function claimUSDC() external {
        uint256 amount = claimableUSDC[msg.sender];
        require(amount > 0, "Nothing to claim");
        claimableUSDC[msg.sender] = 0;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit Claimed(msg.sender, amount);
    }

    // Kullanıcı NFT claim eder
    function claimNFT(uint256 tokenId) external {
        require(claimableNFT[msg.sender][tokenId], "No NFT to claim");
        claimableNFT[msg.sender][tokenId] = false;
        badgeNFT.mint(msg.sender, tokenId);
        emit NFTClaimed(msg.sender, tokenId);
    }

    // Birleşik claim (USDC + tüm bekleyen NFT'ler)
    function claimAll(uint256[] calldata nftTokenIds) external {
        // USDC
        uint256 amount = claimableUSDC[msg.sender];
        if (amount > 0) {
            claimableUSDC[msg.sender] = 0;
            require(usdc.transfer(msg.sender, amount), "Transfer failed");
            emit Claimed(msg.sender, amount);
        }

        // NFT'ler
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            if (claimableNFT[msg.sender][nftTokenIds[i]]) {
                claimableNFT[msg.sender][nftTokenIds[i]] = false;
                badgeNFT.mint(msg.sender, nftTokenIds[i]);
                emit NFTClaimed(msg.sender, nftTokenIds[i]);
            }
        }
    }

    // Pool bakiyelerini oku
    function getPoolBalances() external view returns (
        uint256 weekly,
        uint256 monthly,
        uint256 season,
        uint256 achievement
    ) {
        return (weeklyPool, monthlyPool, seasonPool, achievementPool);
    }
}
