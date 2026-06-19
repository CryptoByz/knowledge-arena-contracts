import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const RPC_URLS: Record<string, string> = {
  "84532": "https://sepolia.base.org",
  "8453": "https://mainnet.base.org",
  "5042002": "https://rpc.testnet.arc.network",
  "42220": "https://forno.celo.org",
};

// Minimal ABI to query owner
const MINIMAL_ABI = [
  "function owner() view returns (address)"
];

async function checkOwner(networkName: string, chainId: string) {
  try {
    const deploymentPath = path.join(__dirname, `../deployments/${chainId}.json`);
    if (!fs.existsSync(deploymentPath)) {
      console.log(`[-] No deployment file for chainId ${chainId} (${networkName})`);
      return;
    }
    const data = JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));
    const quizAddress = data.dailyQuiz;
    if (!quizAddress) {
      console.log(`[-] No DailyQuiz address in ${chainId}.json`);
      return;
    }

    const rpcUrl = RPC_URLS[chainId];
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const contract = new ethers.Contract(quizAddress, MINIMAL_ABI, provider);
    const owner = await contract.owner();
    console.log(`[+] ${networkName} (Chain: ${chainId})`);
    console.log(`    DailyQuiz: ${quizAddress}`);
    console.log(`    Contract Owner: ${owner}`);
  } catch (err: any) {
    console.log(`[x] Failed to check ${networkName}: ${err.message}`);
  }
}

async function main() {
  console.log("Checking contract owners across networks...\n");
  await checkOwner("Base Sepolia", "84532");
  await checkOwner("Base Mainnet", "8453");
  await checkOwner("ARC Testnet", "5042002");
  await checkOwner("Celo Mainnet", "42220");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
