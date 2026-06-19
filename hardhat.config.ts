import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY || "0x" + "0".repeat(64);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    arcTestnet: {
      url: process.env.ARC_RPC_URL || "",
      accounts: [PRIVATE_KEY],
      chainId: 5042002,
    },
    baseMainnet: {
     url: process.env.BASE_MAINNET_RPC_URL || "https://mainnet.base.org",
     accounts: [PRIVATE_KEY],
     chainId: 8453,
    },
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
      accounts: [PRIVATE_KEY],
      chainId: 84532,
    }
  }
};

export default config;
