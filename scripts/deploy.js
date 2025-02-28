const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // 📌 Deploy RewardToken (ERC20)
  const RewardToken = await ethers.getContractFactory("RewardToken");
  const rewardToken = await RewardToken.deploy();
  await rewardToken.waitForDeployment();
  console.log("RewardToken deployed at:", rewardToken.target);

  // 📌 Deploy LimitedEditionNFT (ERC721)
  const LimitedEditionNFT =
    await ethers.getContractFactory("LimitedEditionNFT");
  const nft = await LimitedEditionNFT.deploy(999000, 888000);
  await nft.waitForDeployment();
  console.log("LimitedEditionNFT deployed at:", nft.target);

  // 📌 Deploy StakeNFT (upgradeable)
  const StakeNFT = await ethers.getContractFactory("StakeNFT");
  const stakeNFT = await upgrades.deployProxy(
    StakeNFT,
    [nft.target, rewardToken.target, 100], // Args for initialize
    { initializer: "initialize", kind: "uups" },
  );
  console.log("StakeNFT deployed at:", stakeNFT.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// Deploying contracts with account: 0xE7234457734b5Fa98ac230Aa2e5bC9A2d17A1C27
// RewardToken deployed at:          0xf4016CCBC8d3D9d3b19Fa26D4a8C426678e80F3B
// LimitedEditionNFT deployed at:    0x0aEe5C830A1744aFBEfba9A63eC1a384f159f6b9
// StakeNFT deployed at:             0x95a210ffDCb44d53Ef6eF22fe18262B357a81a6c
// Verifying implementation:         0xfD400D39A1A94A52611E301256347770b885329B

// Deploying contracts with account: 0xE7234457734b5Fa98ac230Aa2e5bC9A2d17A1C27
// RewardToken deployed at:          0x800686901931e22da13A4B20023706B55f464Fc5
// LimitedEditionNFT deployed at:    0x5626E294D81343774Dd8F38b0ac8163d589E9c1e
// StakeNFT deployed at:             0x3194EABff52D3A1102688D8759780283C0f66A8E
