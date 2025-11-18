// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LotteryStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/ILotteryCommon.sol";
/**
 * @title LotteryCommon
 * @dev Contains common ERC721 logic and an internal solve function.
 * Inherits all storage variables from LotteryStorage.
 */
abstract contract LotteryCommon is LotteryStorage, Ownable, ERC721,ILotteryCommon {
    constructor(string memory name_, string memory symbol_, address owner_) ERC721(name_, symbol_) Ownable(owner_) {}

    // Returns the base prize for a ticket.
    function getBasePrize(uint256 ticketId) public view returns (uint256) {
        Ticket storage ticket = tickets[ticketId];
        if (!ticket.revealed && block.timestamp > ticket.revealDeadline) {
            return MAX_RANDOM;
        }
        return ticket.randomComponent;
    }

    /**
     * @dev Internal function that contains the solve logic.
     * @param ticketId The id of the ticket.
     * @param x The user-provided number.
     * @param N The modulus parameter for the challenge.
     * @param magic The challenge magic number.
     */
    function _solveMulmodInternal(
        uint256 ticketId,
        uint256 x,
        uint256 N,
        uint256 magic
    ) internal {
        require(ownerOf(ticketId) == msg.sender, "Not ticket owner");
        Ticket storage ticket = tickets[ticketId];
        require(!ticket.redeemed, "Ticket redeemed");
        require(block.timestamp < ticket.expirationTime, "Ticket expired");
        // Added minimum redemption delay.
        require(block.timestamp >= ticket.purchaseTime + REDEEM_DELAY, "Redemption delay not met");
        
        // Check if this challenge has already been solved
        require(!solvedChallenges[magic], "Challenge already solved");

        uint256 basePrize = getBasePrize(ticketId);
        // Multiply the bonus (magic) by 10**6 so that, e.g., solveMulmod... rewards an additional USDC bonus.
        uint256 skillBonus = (mulmod(x, x, N) == magic ? magic * 10 ** 6 : 0);
        uint256 prize = basePrize + skillBonus;

        // If the challenge was solved successfully, mark it as solved
        if (skillBonus > 0) {
            solvedChallenges[magic] = true;
        }

        ticket.redeemed = true;
        liquidity -= prize;
        require(usdc.transfer(msg.sender, prize), "USDC transfer failed");
        _burn(ticketId);
    }
}
