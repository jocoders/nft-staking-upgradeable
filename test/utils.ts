import { ethers } from "ethers";

export const mintWithSignNFT = async (
  nftContract: any,
  to: string,
  value: number,
  owner: any,
  ticketNumber: number,
): Promise<number> => {
  const message = "Authorize minting";

  const signature = await owner.signMessage({ message });
  const { r, s, v } = ethers.Signature.from(signature);

  await nftContract.write.mint([to, ticketNumber, v, r, s, message], {
    value,
  });

  const balance = (await nftContract.read.balanceOf([to])) as BigInt;

  return Number(balance);
};

export const mintBaseNFT = async (
  nftContract: any,
  to: string,
  value: number,
): Promise<number> => {
  await nftContract.write.mint([to], {
    value,
  });

  const balance = (await nftContract.read.balanceOf([to])) as BigInt;

  return Number(balance);
};

export const stakeNFT = async (
  stakeContract: any,
  nftContract: any,
  tokenId: number,
  to: any,
) => {
  await nftContract.write.approve([stakeContract.address, tokenId], {
    account: to.account,
  });
  await stakeContract.write.depositNFT([tokenId], {
    account: to.account,
  });

  const balanceStake = (await nftContract.read.balanceOf([
    stakeContract.address,
  ])) as BigInt;
  const balanceTo = (await nftContract.read.balanceOf([
    to.account.address,
  ])) as BigInt;

  return { balanceStake, balanceTo };
};
