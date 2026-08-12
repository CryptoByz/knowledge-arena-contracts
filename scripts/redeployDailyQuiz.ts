import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  console.log(`\nRedeploying DailyQuiz on: ${network.name} (chainId: ${network.chainId})`);
  console.log(`Deployer: ${deployer.address}`);

  const playerProfileAddress = "0xc8Ba5dab61Ed592AA591a56F3880cDC892d78767";
  const achievementManagerAddress = "0x413cE89ac030b44a261f97Fdcb3D4D49a92322E7";
  const adminWallet = "0xb98C170Ee93365A19928059a71c23629897150F9";

  let feeToken = "0x0000000000000000000000000000000000000000";
  let entryFee = 0n;

  const chainId = Number(network.chainId);
  if (chainId === 5042002) {
    // ARC Testnet: 2 USDC (native, 6 decimals)
    feeToken = "0x0000000000000000000000000000000000000000";
    entryFee = ethers.parseUnits("2.00", 6);
  } else if (chainId === 42220) {
    // Celo: 0.02 USDC (ERC20, 6 decimals)
    feeToken = "0x765DE816845861e75A25fCA122bb6898B8B1282a";
    entryFee = ethers.parseUnits("0.02", 6);
  } else if (chainId === 8453) {
    // Base: 0.0003 ETH (native, 18 decimals)
    feeToken = "0x0000000000000000000000000000000000000000";
    entryFee = ethers.parseUnits("0.0003", 18);
  } else if (chainId === 84532) {
    // Base Sepolia: 2.00 USDC (ERC20, 6 decimals)
    feeToken = "0x036cbd53842c5426634e7929541ec2318f3dcf7e";
    entryFee = ethers.parseUnits("2.00", 6);
  }

  console.log(`Config: feeToken=${feeToken}, entryFee=${entryFee.toString()} wei, adminWallet=${adminWallet}`);

  console.log("1. Deploying new DailyQuiz contract...");
  const DailyQuiz = await ethers.getContractFactory("DailyQuiz");
  const dailyQuiz = await DailyQuiz.deploy(
    playerProfileAddress,
    achievementManagerAddress,
    feeToken,
    entryFee,
    adminWallet
  );
  await dailyQuiz.waitForDeployment();
  const newQuizAddr = await dailyQuiz.getAddress();
  console.log(`   New DailyQuiz deployed at: ${newQuizAddr}`);

  console.log("2. Setting quiz contract address in PlayerProfile...");
  const PlayerProfile = await ethers.getContractAt("PlayerProfile", playerProfileAddress);
  await (await PlayerProfile.setQuizContract(newQuizAddr)).wait();
  console.log("   PlayerProfile updated.");

  console.log("3. Setting quiz contract address in AchievementManager...");
  const AchievementManager = await ethers.getContractAt("AchievementManager", achievementManagerAddress);
  await (await AchievementManager.setQuizContract(newQuizAddr)).wait();
  console.log("   AchievementManager updated.");

  console.log("\n=== REDEPLOYMENT COMPLETE ===");
  console.log(`New DailyQuiz Address: ${newQuizAddr}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
