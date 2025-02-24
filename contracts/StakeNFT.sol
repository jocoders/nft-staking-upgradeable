// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title StakeNFT - A contract for staking NFTs to earn rewards
/// @author Your Name
/// @notice This contract allows users to stake NFTs and earn rewards based on staking duration
/// @dev This contract implements IERC721Receiver to handle receiving NFTs and uses UUPS for upgradability
contract StakeNFT is IERC721Receiver, Ownable2Step, UUPSUpgradeable {
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
    error InvalidNft();
    error InvalidRewardToken();

    /// @notice Initializes the contract with NFT and reward token addresses, and reward rate
    /// @dev Sets the immutable addresses for the NFT and reward token, and initializes staking reward rate
    /// @param _nftContract The address of the NFT contract
    /// @param _rewardToken The address of the reward token contract
    /// @param _rewardPerSecond The reward rate per second for staking
    constructor(address _nftContract, address _rewardToken, uint256 _rewardPerSecond) Ownable(msg.sender) {
        require(_nftContract != address(0), InvalidNft());
        require(_rewardToken != address(0), InvalidRewardToken());

        nft = IERC721(_nftContract);
        rewardToken = IERC20(_rewardToken);
        rewardPerSecond = _rewardPerSecond;
    }

    /// @notice Changes the reward rate per second
    /// @dev Can only be called by the owner
    /// @param _rewardPerSecond The new reward rate per second
    function changeRewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        rewardPerSecond = _rewardPerSecond;
    }

    /// @notice Handles the receipt of an NFT
    /// @dev Required to be implemented due to IERC721Receiver
    /// @param operator The address which called `safeTransferFrom` function
    /// @param from The address which previously owned the token
    /// @param id The NFT identifier which is being transferred
    /// @param data Additional data with no specified format
    /// @return bytes4 Returns `IERC721Receiver.onERC721Received.selector`
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external override returns (bytes4) {
        require(nft.ownerOf(id) == address(this), WrongNftContract(msg.sender, id));

        uint256 stakeData = _packData(from, block.timestamp);
        stakings[id] = stakeData;
        emit Staked(from, id);

        return this.onERC721Received.selector;
    }

    /// @notice Calculates the reward for a given tokenId
    /// @dev Returns the reward calculated based on the staking duration
    /// @param tokenId The identifier of the staked NFT
    /// @return reward The calculated reward
    function checkReward(uint256 tokenId) public view returns (uint256 reward) {
        uint256 timestamp = uint256(uint96(stakings[tokenId]));

        if (timestamp > 0) {
            reward = (block.timestamp - timestamp) * rewardPerSecond;
        }
    }

    /// @notice Allows a user to deposit an NFT for staking
    /// @dev Transfers the NFT to the contract and records the staking time
    /// @param tokenId The identifier of the NFT to stake
    function depositNFT(uint256 tokenId) external {
        require(stakings[tokenId] == 0, TokenAlreadyStaked(tokenId));

        address sender = msg.sender;
        stakings[tokenId] = _packData(sender, block.timestamp);
        nft.transferFrom(sender, address(this), tokenId);
        emit Staked(sender, tokenId);
    }

    /// @notice Withdraws the reward for a staked NFT
    /// @dev Transfers the accumulated reward to the staker
    /// @param tokenId The identifier of the staked NFT
    function withdrawReward(uint256 tokenId) external {
        (address owner, uint256 reward) = _getStakeDetails(tokenId);
        require(reward > 0, NoReward(reward));

        stakings[tokenId] = _packData(owner, block.timestamp);
        _transferReward(owner, reward);
    }

    /// @notice Withdraws a staked NFT and any accumulated rewards
    /// @dev Transfers both the NFT and the reward to the staker
    /// @param tokenId The identifier of the staked NFT
    function withdrawNFT(uint256 tokenId) external {
        (address owner, uint256 reward) = _getStakeDetails(tokenId);
        delete stakings[tokenId];

        if (reward > 0) {
            _transferReward(owner, reward);
        }

        nft.safeTransferFrom(address(this), owner, tokenId);
        emit UnStaked(owner, tokenId);
    }

    /// @dev Authorizes an upgrade to a new implementation of the contract
    /// @param newImplementation The address of the new contract implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @dev Packs the staker's address and the timestamp into a single uint256
    /// @param user The address of the staker
    /// @param timestamp The timestamp when the NFT was staked
    /// @return The packed data
    function _packData(address user, uint256 timestamp) private pure returns (uint256) {
        return (uint256(uint160(user)) << 96) | timestamp;
    }

    /// @dev Transfers the reward tokens to the staker
    /// @param to The address of the staker
    /// @param amount The amount of reward tokens to transfer
    function _transferReward(address to, uint256 amount) private {
        rewardToken.safeTransfer(to, amount);
        emit TransferReward(to, amount);
    }

    /// @dev Retrieves the staking details for a given tokenId
    /// @param tokenId The identifier of the staked NFT
    /// @return owner The address of the staker
    /// @return reward The accumulated reward
    function _getStakeDetails(uint256 tokenId) private view returns (address owner, uint256 reward) {
        owner = address(uint160(stakings[tokenId] >> 96));
        require(msg.sender == owner, NotOwner(msg.sender, owner));
        reward = checkReward(tokenId);
    }
}
