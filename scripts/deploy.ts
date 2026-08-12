import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  console.log(`\nDeploying on: ${network.name} (chainId: ${network.chainId})`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))}\n`);

  const metadataBaseURI = process.env.METADATA_BASE_URI || "https://api.knowledge-arena.xyz/metadata";

  const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
  const delay = async () => { if (network.chainId === 42220n || network.chainId === 8453n) await sleep(3000); };

  console.log("1/4 Deploying BadgeNFT...");
  const BadgeNFT = await ethers.getContractFactory("BadgeNFT");
  const badgeNFT = await BadgeNFT.deploy(metadataBaseURI);
  await badgeNFT.waitForDeployment();
  console.log(`    BadgeNFT: ${await badgeNFT.getAddress()}`);
  await delay();

  console.log("2/4 Deploying PlayerProfile...");
  const PlayerProfile = await ethers.getContractFactory("PlayerProfile");
  const playerProfile = await PlayerProfile.deploy();
  await playerProfile.waitForDeployment();
  console.log(`    PlayerProfile: ${await playerProfile.getAddress()}`);
  await delay();

  console.log("3/4 Deploying AchievementManager...");
  const AchievementManager = await ethers.getContractFactory("AchievementManager");
  const achievementManager = await AchievementManager.deploy(
    await playerProfile.getAddress(),
    await badgeNFT.getAddress()
  );
  await achievementManager.waitForDeployment();
  console.log(`    AchievementManager: ${await achievementManager.getAddress()}`);
  await delay();

  console.log("4/4 Deploying DailyQuiz...");
  const DailyQuiz = await ethers.getContractFactory("DailyQuiz");
  const dailyQuiz = await DailyQuiz.deploy(
    await playerProfile.getAddress(),
    await achievementManager.getAddress()
  );
  await dailyQuiz.waitForDeployment();
  console.log(`    DailyQuiz: ${await dailyQuiz.getAddress()}`);
  await delay();

  console.log("\nSetting up permissions...");
  const quizAddr = await dailyQuiz.getAddress();

  await (await playerProfile.setQuizContract(quizAddr)).wait();
  console.log("    PlayerProfile: quiz contract set");
  await delay();

  await (await playerProfile.setAchievementManager(await achievementManager.getAddress())).wait();
  console.log("    PlayerProfile: AchievementManager set");
  await delay();

  await (await achievementManager.setQuizContract(quizAddr)).wait();
  console.log("    AchievementManager: quiz contract set");
  await delay();

  await (await badgeNFT.setAuthorized(await achievementManager.getAddress(), true)).wait();
  console.log("    BadgeNFT: AchievementManager authorized");

  const addresses = {
    network:            network.name,
    chainId:            network.chainId.toString(),
    badgeNFT:           await badgeNFT.getAddress(),
    playerProfile:      await playerProfile.getAddress(),
    achievementManager: await achievementManager.getAddress(),
    dailyQuiz:          await dailyQuiz.getAddress(),
  };

  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log(JSON.stringify(addresses, null, 2));

  fs.mkdirSync("./deployments", { recursive: true });
  fs.writeFileSync(`./deployments/${network.chainId}.json`, JSON.stringify(addresses, null, 2));
  console.log(`\nAddresses saved to ./deployments/${network.chainId}.json`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
