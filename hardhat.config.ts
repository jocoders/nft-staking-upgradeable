import type { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const { API_URL, PRIVATE_KEY, API_KEY } = process.env;

if (!API_URL || !PRIVATE_KEY || !API_KEY) {
  throw new Error("API_URL or PRIVATE_KEY is not set");
}

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: API_URL,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: API_KEY,
    },
  },
};

export default config;
