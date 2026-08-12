import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const accounts = process.env.ADMIN_PRIVATE_KEY ? [process.env.ADMIN_PRIVATE_KEY] : [];

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
      accounts: accounts,
      chainId: 5042002,
    },
    baseMainnet: {
     url: process.env.BASE_MAINNET_RPC_URL || "https://mainnet.base.org",
     accounts: accounts,
     chainId: 8453,
    },
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
      accounts: accounts,
      chainId: 84532,
    },
    celo: {
      url: process.env.CELO_RPC_URL || "https://forno.celo.org",
      accounts: accounts,
      chainId: 42220,
    }
  }
};


export default config;
