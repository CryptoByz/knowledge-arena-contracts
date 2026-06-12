import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  console.log(`\nDeploying on: ${network.name} (chainId: ${network.chainId})`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);

  // Chain'e göre USDC adresi ve platform adresi
  const config: Record<string, { usdc: string; platform: string }> = {
    "5042002": { // ARC Testnet - chain ID doc'tan doğrulanacak
      usdc:     process.env.ARC_USDC_ADDRESS || "",
      platform: deployer.address, // başlangıçta deployer
    },
    "84532": { // Base Sepolia
      usdc:     "0x036CbD53842c5426634e7929541eC2318f3dCF7e", // Base Sepolia USDC
      platform: deployer.address,
    }
  };

  const chainConfig = config[network.chainId.toString()];
  if (!chainConfig) throw new Error(`Unsupported chainId: ${network.chainId}`);
  if (!chainConfig.usdc) throw new Error("USDC address not set");

  // 1. BadgeNFT
  console.log("1/5 Deploying BadgeNFT...");
  const BadgeNFT = await ethers.getContractFactory("BadgeNFT");
  const badgeNFT = await BadgeNFT.deploy(
    process.env.METADATA_BASE_URI || "https://api.knowledge-arena.xyz/metadata"
  );
  await badgeNFT.waitForDeployment();
  console.log(`    BadgeNFT: ${await badgeNFT.getAddress()}`);

  // 2. PlayerProfile
  console.log("2/5 Deploying PlayerProfile...");
  const PlayerProfile = await ethers.getContractFactory("PlayerProfile");
  const playerProfile = await PlayerProfile.deploy();
  await playerProfile.waitForDeployment();
  console.log(`    PlayerProfile: ${await playerProfile.getAddress()}`);

  // 3. AchievementManager
  console.log("3/5 Deploying AchievementManager...");
  const AchievementManager = await ethers.getContractFactory("AchievementManager");
  const achievementManager = await AchievementManager.deploy(
    await playerProfile.getAddress(),
    await badgeNFT.getAddress()
  );
  await achievementManager.waitForDeployment();
  console.log(`    AchievementManager: ${await achievementManager.getAddress()}`);

  // 4. RewardPool
  console.log("4/5 Deploying RewardPool...");
  const RewardPool = await ethers.getContractFactory("RewardPool");
  const rewardPool = await RewardPool.deploy(
    chainConfig.usdc,
    await badgeNFT.getAddress(),
    chainConfig.platform
  );
  await rewardPool.waitForDeployment();
  console.log(`    RewardPool: ${await rewardPool.getAddress()}`);

  // 5. DailyQuiz
  console.log("5/5 Deploying DailyQuiz...");
  const DailyQuiz = await ethers.getContractFactory("DailyQuiz");
  const dailyQuiz = await DailyQuiz.deploy(
    chainConfig.usdc,
    await playerProfile.getAddress(),
    await rewardPool.getAddress(),
    await achievementManager.getAddress()
  );
  await dailyQuiz.waitForDeployment();
  console.log(`    DailyQuiz: ${await dailyQuiz.getAddress()}`);

  // Yetkilendirmeler
  console.log("\nSetting up permissions...");

  const quizAddr = await dailyQuiz.getAddress();

  await (await playerProfile.setQuizContract(quizAddr)).wait();
  console.log("    PlayerProfile: quiz contract set");

  await (await rewardPool.setQuizContract(quizAddr)).wait();
  console.log("    RewardPool: quiz contract set");

  await (await achievementManager.setQuizContract(quizAddr)).wait();
  console.log("    AchievementManager: quiz contract set");

  // BadgeNFT yetkileri
  await (await badgeNFT.setAuthorized(await achievementManager.getAddress(), true)).wait();
  await (await badgeNFT.setAuthorized(await rewardPool.getAddress(), true)).wait();
  console.log("    BadgeNFT: authorized contracts set");

  // Deployment özeti
  const addresses = {
    network:            network.name,
    chainId:            network.chainId.toString(),
    badgeNFT:           await badgeNFT.getAddress(),
    playerProfile:      await playerProfile.getAddress(),
    achievementManager: await achievementManager.getAddress(),
    rewardPool:         await rewardPool.getAddress(),
    dailyQuiz:          await dailyQuiz.getAddress(),
    usdc:               chainConfig.usdc,
  };

  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log(JSON.stringify(addresses, null, 2));

  // Adresleri dosyaya kaydet
  const fs = await import("fs");
  const outPath = `./deployments/${network.chainId}.json`;
  fs.mkdirSync("./deployments", { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));
  console.log(`\nAddresses saved to ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
