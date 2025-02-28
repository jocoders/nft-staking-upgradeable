const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "0x95a210ffDCb44d53Ef6eF22fe18262B357a81a6c"; // Proxy contract address
  const adminAddress = "0xE7234457734b5Fa98ac230Aa2e5bC9A2d17A1C27"; // Admin address

  console.log(`Upgrading StakeNFT at proxy: ${proxyAddress}`);

  const StakeNFTV2 = await ethers.getContractFactory("StakeNFT"); // Load a new version
  const upgraded = await upgrades.upgradeProxy(proxyAddress, StakeNFTV2);

  console.log(`✅ StakeNFT upgraded! Proxy is still at: ${upgraded.target}`);
  console.log(`Calling initialize to set admin at proxy: ${proxyAddress}`);

  const stakeNFT = await ethers.getContractAt("StakeNFT", proxyAddress);
  const tx = await stakeNFT.initialize(adminAddress);
  await tx.wait();

  console.log(`✅ Admin has been successfully set to: ${adminAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
