import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre, { network } from "hardhat";
import { mintBaseNFT, mintWithSignNFT, stakeNFT } from "./utils";

const BASIC_PRICE = 990000;
const DISCOUNT_PRICE = 770000;
const TOKEN_DECIMALS = 18;
const REWARD = 9;
const REWARD_TOKEN_SUPPLY = BigInt(1_000_000) * BigInt(10 ** TOKEN_DECIMALS);

describe("StakeNFT", function () {
  async function deployFixture() {
    const [owner, Alice, Bob] = await hre.viem.getWalletClients();

    const rewardToken = await hre.viem.deployContract("RewardToken", []);
    const nft = await hre.viem.deployContract("LimitedEditionNFT" as any, [
      BASIC_PRICE,
      DISCOUNT_PRICE,
    ]);
    const stake = await hre.viem.deployContract("StakeNFT" as any, []);
    await stake.write.initialize([nft.address, rewardToken.address, REWARD]);
    await rewardToken.write.mint([stake.address, REWARD_TOKEN_SUPPLY]);
    const publicClient = await hre.viem.getPublicClient();

    return {
      publicClient,
      rewardToken,
      nft,
      stake,
      owner,
      Alice,
      Bob,
    };
  }

  it("should mint exact amount of RewardToken", async function () {
    const { publicClient, rewardToken, nft, stake, owner, Alice, Bob } =
      await loadFixture(deployFixture);

    const rewardTokenBalance = await rewardToken.read.balanceOf([
      stake.address,
    ]);
    console.log(`RewardToken balance: ${rewardTokenBalance.toString()}`);
    expect(Number(rewardTokenBalance)).to.equal(Number(REWARD_TOKEN_SUPPLY));
  });

  it("should mint NFT with basic price", async function () {
    const { publicClient, rewardToken, nft, stake, owner, Alice, Bob } =
      await loadFixture(deployFixture);

    await mintBaseNFT(nft, Alice.account.address, BASIC_PRICE);
    await mintBaseNFT(nft, Alice.account.address, BASIC_PRICE);
    const aliceBalance = await mintBaseNFT(
      nft,
      Alice.account.address,
      BASIC_PRICE,
    );
    expect(Number(aliceBalance)).to.equal(3);

    await mintBaseNFT(nft, Bob.account.address, BASIC_PRICE);
    await mintBaseNFT(nft, Bob.account.address, BASIC_PRICE);
    const bobBalance = await mintBaseNFT(nft, Bob.account.address, BASIC_PRICE);
    expect(Number(bobBalance)).to.equal(3);

    const remainingSupply = (await nft.read.remainingSupply()) as BigInt;
    const maxSupply = await nft.read.MAX_SUPPLY();

    expect(Number(remainingSupply)).to.equal(Number(maxSupply) - 6);
  });

  it("should mint NFT with discount price", async function () {
    const { publicClient, rewardToken, nft, stake, owner, Alice, Bob } =
      await loadFixture(deployFixture);
    const ticketNumber0 = 0;
    await mintWithSignNFT(
      nft,
      Alice.account.address,
      DISCOUNT_PRICE,
      owner,
      ticketNumber0,
    );
    const ticketNumber1 = 1;
    const aliceBalance = await mintWithSignNFT(
      nft,
      Alice.account.address,
      DISCOUNT_PRICE,
      owner,
      ticketNumber1,
    );

    console.log(`Alice NFT balance: ${aliceBalance.toString()}`);
    expect(Number(aliceBalance)).to.equal(2);
  });

  it("should return 0 reward if NFT is not staked", async function () {
    const { stake } = await loadFixture(deployFixture);

    const tokenId = 0;
    const reward = await stake.read.checkReward([tokenId]);
    expect(Number(reward)).to.equal(0);
  });

  it("should sucessfully stake NFT", async function () {
    const { stake, nft, owner, Alice } = await loadFixture(deployFixture);
    const TOKEN_ID = 1768;

    await mintBaseNFT(nft, Alice.account.address, BASIC_PRICE);
    const ownerOf = await nft.read.ownerOf([TOKEN_ID]);
    expect(String(ownerOf).toUpperCase()).to.equal(
      Alice.account.address.toUpperCase(),
    );

    const { balanceStake, balanceTo } = await stakeNFT(
      stake,
      nft,
      TOKEN_ID,
      Alice,
    );
    expect(Number(balanceStake)).to.equal(1);
    expect(Number(balanceTo)).to.equal(0);
  });

  it("should sucessfully check reward", async function () {
    const { stake, nft, owner, Alice } = await loadFixture(deployFixture);
    const TOKEN_ID = 1768;
    await mintBaseNFT(nft, Alice.account.address, BASIC_PRICE);
    const ownerOf = await nft.read.ownerOf([TOKEN_ID]);
    expect(String(ownerOf).toUpperCase()).to.equal(
      Alice.account.address.toUpperCase(),
    );

    const { balanceStake, balanceTo } = await stakeNFT(
      stake,
      nft,
      TOKEN_ID,
      Alice,
    );

    expect(Number(balanceStake)).to.equal(1);
    await network.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await network.provider.send("evm_mine", []);

    const reward = await stake.read.checkReward([TOKEN_ID]);
    expect(Number(reward)).to.equal(REWARD * 86400 * 7);
  });

  it("should sucessfully withdraw reward", async function () {
    const { stake, nft, rewardToken, Alice } = await loadFixture(deployFixture);
    const TOKEN_ID = 1768;
    await mintBaseNFT(nft, Alice.account.address, BASIC_PRICE);
    const ownerOf = await nft.read.ownerOf([TOKEN_ID]);
    expect(String(ownerOf).toUpperCase()).to.equal(
      Alice.account.address.toUpperCase(),
    );
    const { balanceStake } = await stakeNFT(stake, nft, TOKEN_ID, Alice);
    expect(Number(balanceStake)).to.equal(1);
    await network.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await network.provider.send("evm_mine", []);
    const reward = await stake.read.checkReward([TOKEN_ID]);
    expect(Number(reward)).to.equal(REWARD * 86400 * 7);
    await stake.write.withdrawReward([TOKEN_ID], {
      account: Alice.account,
    });
    const remainedBalanceStake = await stake.read.checkReward([TOKEN_ID]);
    expect(Number(remainedBalanceStake)).to.equal(0);

    const balanceRewardToken = await rewardToken.read.balanceOf([
      Alice.account.address,
    ]);
    expect(Number(balanceRewardToken)).to.greaterThan(Number(reward));
  });

  it("should sucessfully withdraw NFT", async function () {
    const { stake, nft, rewardToken, Alice } = await loadFixture(deployFixture);
    const TOKEN_ID = 1768;
    await mintBaseNFT(nft, Alice.account.address, BASIC_PRICE);
    const ownerOf = await nft.read.ownerOf([TOKEN_ID]);
    expect(String(ownerOf).toUpperCase()).to.equal(
      Alice.account.address.toUpperCase(),
    );
    const { balanceStake } = await stakeNFT(stake, nft, TOKEN_ID, Alice);
    expect(Number(balanceStake)).to.equal(1);
    await network.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await network.provider.send("evm_mine", []);
    const reward = await stake.read.checkReward([TOKEN_ID]);
    expect(Number(reward)).to.equal(REWARD * 86400 * 7);

    await stake.write.withdrawNFT([TOKEN_ID], {
      account: Alice.account,
    });
    const remainedBalanceStake = await stake.read.checkReward([TOKEN_ID]);
    expect(Number(remainedBalanceStake)).to.equal(0);

    const balanceRewardToken = await rewardToken.read.balanceOf([
      Alice.account.address,
    ]);
    expect(Number(balanceRewardToken)).to.greaterThan(Number(reward));

    const balanceTo = (await nft.read.balanceOf([
      Alice.account.address,
    ])) as BigInt;
    expect(Number(balanceTo)).to.equal(1);
  });
});
