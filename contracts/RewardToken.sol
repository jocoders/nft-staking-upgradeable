// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title RewardToken for incentivizing platform engagement
/// @author Your Name
/// @notice This contract handles the creation and management of an ERC20 Reward Token
/// @dev This contract extends OpenZeppelin's ERC20, ERC20Burnable, and Ownable2Step
contract RewardToken is ERC20, Ownable2Step, ERC20Burnable {
    /// @notice Initializes the contract with token details and sets the owner
    /// @dev The constructor sets up an ERC20 token named "RewardToken" with symbol "RTK"
    constructor() ERC20("RewardToken", "RTK") Ownable(msg.sender) {}

    /// @notice Allows the owner to mint new tokens to a specified address
    /// @dev Access control is enforced by the `onlyOwner` modifier
    /// @param to The address that will receive the minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
