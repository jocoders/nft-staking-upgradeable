// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
/// @title StakeNFT - A contract for staking NFTs to earn rewards
/// @author Your Name
/// @notice This contract allows users to stake NFTs and earn rewards based on staking duration
/// @dev This contract implements IERC721Receiver to handle receiving NFTs and uses UUPS for upgradability
contract StakeNFT is IERC721Receiver, Initializable, UUPSUpgradeable, AccessControl {
    using SafeERC20 for IERC20;

    IERC721 public nft;
    IERC20 public rewardToken;

    mapping(uint256 => uint256) public stakings;
    uint256 public rewardPerSecond;

    uint256 private lastUpgradeTime;

    address private admin;

    event Staked(address indexed user, uint256 indexed tokenId);
    event UnStaked(address indexed user, uint256 indexed tokenId);
    event TransferReward(address indexed user, uint256 reward);
    event AdminRoleGranted(address indexed account);
    event ForceTransferStake(address indexed oldOwner, address indexed newOwner, uint256 indexed tokenId);

    error NoReward(uint256 availableReward);
    error NotOwner(address sender, address owner);
    error TokenAlreadyStaked(uint256 tokenId);
    error WrongNftContract(address sender, uint256 nftId);
    error InvalidNft();
    error InvalidRewardToken();
    error UpgradeTooSoon();
    error NotAdmin();
    error InvalidAdmin();
    error TokenNotStaked(uint256 tokenId);
    error InvalidToAddress();

    modifier onlyAdmin() {
        require(msg.sender == admin, NotAdmin());
        _;
    }

    /// @notice Initializes the contract with admin address
    /// @dev Sets the immutable addresses for the NFT and reward token, and initializes staking reward rate
    /// @param _admin The address of the admin
    function initialize(address _admin) public reinitializer(2) {
        require(_admin != address(0), InvalidAdmin());
        admin = _admin;
        emit AdminRoleGranted(_admin);
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

    function changeAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), InvalidAdmin());
        admin = _admin;
        emit AdminRoleGranted(_admin);
    }

    function forceTranferStake(uint256 tokenId, address to) external onlyAdmin {
        require(to != address(0), InvalidToAddress());
        require(stakings[tokenId] != 0, TokenNotStaked(tokenId));

        (address oldOwner, ) = _getStakeDetails(tokenId);
        uint256 timestamp = uint256(uint96(stakings[tokenId]));
        stakings[tokenId] = _packData(to, timestamp);
        emit ForceTransferStake(oldOwner, to, tokenId);
    }

    /// @dev Authorizes an upgrade to a new implementation of the contract
    /// @param newImplementation The address of the new contract implementation
    function _authorizeUpgrade(address newImplementation) internal override {
        require(block.timestamp >= lastUpgradeTime + 1 days, UpgradeTooSoon());
        lastUpgradeTime = block.timestamp;
    }

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
