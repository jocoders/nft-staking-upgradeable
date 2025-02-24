// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Limited Edition NFT
/// @author Your Name
/// @notice This contract manages the minting and distribution of limited edition NFTs
/// @dev This contract utilizes OpenZeppelin's ERC721, ERC2981, Ownable2Step, and ReentrancyGuard
contract LimitedEditionNFT is Ownable2Step, ERC721, ERC2981, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public immutable basePrice;
    uint256 public immutable discountPrice;

    uint256 public remainingSupply = 1768;
    uint256 public constant MAX_SUPPLY = 1768;

    uint256 private constant MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256[3] private discountBitmap = [MAX_INT, MAX_INT, MAX_INT];

    error AlreadyMinted();
    error InsufficientFunds();
    error InvalidAddress(address to);
    error InvalidTicketNumber();
    error InvalidSignature();
    error MaxSupplyReached();
    error WithdrawFailed(address to);

    /// @notice Validates the minting process, ensuring there are tokens left and sufficient funds
    /// @dev This modifier checks for remaining supply and compares the sent value against the price
    /// @param to The address attempting to mint
    /// @param price The price at which the token is being minted
    modifier validateMint(address to, uint256 price) {
        require(remainingSupply > 0, MaxSupplyReached());
        require(msg.value >= price, InsufficientFunds());
        _;
    }

    /// @notice Initializes the contract with specified prices and sets the default royalty
    /// @dev Sets immutable values for basePrice and discountPrice, and initializes the ERC721 token
    /// @param _basePrice The price for a standard mint
    /// @param _discountPrice The price for a discounted mint
    constructor(uint256 _basePrice, uint256 _discountPrice) Ownable(msg.sender) ERC721("LimitedEditionNFT", "LENFT") {
        basePrice = _basePrice;
        discountPrice = _discountPrice;
        _setDefaultRoyalty(msg.sender, 250);
    }

    /// @notice Checks if a given interfaceId is supported by the contract
    /// @dev Overrides ERC721 and ERC2981 supportsInterface methods
    /// @param interfaceId The interface identifier to check
    /// @return bool indicating support for the interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    /// @notice Mints a new token to a given address with a discount if the ticket is valid
    /// @dev Requires a valid signature and checks if the ticket has already been used
    /// @param to The address to mint the token to
    /// @param ticketNumber The ticket number used for the discount
    /// @param v, r, s Components of the ECDSA signature
    /// @param message The signed message to verify
    function mint(
        address to,
        uint256 ticketNumber,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata message
    ) external payable nonReentrant validateMint(to, discountPrice) {
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        require(signedMessageHash.recover(v, r, s) == owner(), InvalidSignature());
        require(ticketNumber < discountBitmap.length * 256, InvalidTicketNumber());

        uint256 storageOffset = ticketNumber / 256;
        uint256 offsetWithin256 = ticketNumber % 256;
        uint256 storedBit = discountBitmap[storageOffset];
        uint256 storedVal = (storedBit >> offsetWithin256) & uint256(1);
        require(storedVal == 1, AlreadyMinted());

        discountBitmap[storageOffset] = storedBit & ~(uint256(1) << offsetWithin256);
        _mintNFT(to);
    }

    /// @notice Mints a new token to a given address at the base price
    /// @dev This function allows minting without any discounts
    /// @param to The address to mint the token to
    function mint(address to) external payable nonReentrant validateMint(to, basePrice) {
        _mintNFT(to);
    }

    /// @notice Allows the owner to withdraw funds to a specified address
    /// @dev Ensures the withdrawal address is not zero
    /// @param to The address to which the funds will be sent
    /// @param amount The amount to withdraw
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), InvalidAddress(to));
        (bool success, ) = to.call{ value: amount }("");
        require(success, WithdrawFailed(to));
    }

    /// @dev Internal function to mint the NFT, decrementing the remaining supply
    /// @param to The address receiving the NFT
    function _mintNFT(address to) private {
        _safeMint(to, remainingSupply);

        unchecked {
            --remainingSupply;
        }
    }
}
