// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

    modifier validateMint(address to, uint256 price) {
        require(remainingSupply > 0, MaxSupplyReached());
        require(msg.value >= price, InsufficientFunds());
        _;
    }

    constructor(uint256 _basePrice, uint256 _discountPrice) Ownable(msg.sender) ERC721("LimitedEditionNFT", "LENFT") {
        basePrice = _basePrice;
        discountPrice = _discountPrice;
        _setDefaultRoyalty(msg.sender, 250);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    function mint(
        address to,
        uint256 ticketNumber,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata message
    ) external payable nonReentrant validateMint(to, discountPrice) {
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(message)));
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

    function mint(address to) external payable nonReentrant validateMint(to, basePrice) {
        _mintNFT(to);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), InvalidAddress(to));
        (bool success, ) = to.call{ value: amount }("");
        require(success, WithdrawFailed(to));
    }

    function _mintNFT(address to) private {
        _safeMint(to, remainingSupply);

        unchecked {
            --remainingSupply;
        }
    }
}
