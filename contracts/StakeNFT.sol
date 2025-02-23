// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract StakeNFT is IERC721Receiver, Ownable2Step, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IERC721 public immutable nft;
    IERC20 public immutable rewardToken;

    mapping(uint256 => uint256) public stakings;
    uint256 public rewardPerSecond;

    event Staked(address indexed user, uint256 indexed tokenId);
    event UnStaked(address indexed user, uint256 indexed tokenId);
    event TransferReward(address indexed user, uint256 reward);

    error NoReward(uint256 availableReward);
    error NotOwner(address sender, address owner);
    error TokenAlreadyStaked(uint256 tokenId);
    error WrongNftContract(address sender, uint256 nftId);
    error RewardTransferFailed();

    error InvalidNft();
    error InvalidRewardToken();

    constructor(address _nftContract, address _rewardToken, uint256 _rewardPerSecond) Ownable(msg.sender) {
        require(_nftContract != address(0), InvalidNft());
        require(_rewardToken != address(0), InvalidRewardToken());

        nft = IERC721(_nftContract);
        rewardToken = IERC20(_rewardToken);
        rewardPerSecond = _rewardPerSecond;
    }

    function changeRewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        rewardPerSecond = _rewardPerSecond;
    }

    function onERC721Received(
        address /* operator */,
        address from,
        uint256 id,
        bytes calldata /* data */
    ) external override returns (bytes4) {
        require(nft.ownerOf(id) == address(this), WrongNftContract(msg.sender, id));

        uint256 stakeData = packData(from, block.timestamp);
        stakings[id] = stakeData;
        emit Staked(from, id);

        return this.onERC721Received.selector;
    }

    function checkReward(uint256 tokenId) public view returns (uint256 reward) {
        uint256 timestamp = uint256(uint96(stakings[tokenId]));

        if (timestamp > 0) {
            reward = (block.timestamp - timestamp) * rewardPerSecond;
        }
    }

    function depositNFT(uint256 tokenId) external {
        require(stakings[tokenId] == 0, TokenAlreadyStaked(tokenId));

        address sender = msg.sender;
        stakings[tokenId] = packData(sender, block.timestamp);
        nft.transferFrom(sender, address(this), tokenId);
        emit Staked(sender, tokenId);
    }

    function withdrawReward(uint256 tokenId) external {
        (address owner, uint256 reward) = getStakeDetails(tokenId);
        require(reward > 0, NoReward(reward));

        stakings[tokenId] = packData(owner, block.timestamp);
        transferReward(owner, reward);
    }

    function withdrawNFT(uint256 tokenId) external {
        (address owner, uint256 reward) = getStakeDetails(tokenId);
        delete stakings[tokenId];

        if (reward > 0) {
            transferReward(owner, reward);
        }

        nft.safeTransferFrom(address(this), owner, tokenId);
        emit UnStaked(owner, tokenId);
    }

    function packData(address user, uint256 timestamp) private pure returns (uint256) {
        return (uint256(uint160(user)) << 96) | timestamp;
    }

    function transferReward(address to, uint256 amount) private {
        rewardToken.safeTransfer(to, amount);
        emit TransferReward(to, amount);
    }

    function getStakeDetails(uint256 tokenId) private view returns (address owner, uint256 reward) {
        owner = address(uint160(stakings[tokenId] >> 96));
        require(msg.sender == owner, NotOwner(msg.sender, owner));
        reward = checkReward(tokenId);
    }
}
