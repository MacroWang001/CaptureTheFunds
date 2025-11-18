// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ILotteryCommon  is IERC721{
    /**
     * @notice Returns the base prize for a given ticket.
     * @param ticketId The id of the ticket.
     * @return The base prize amount.
     */
    function getBasePrize(uint256 ticketId) external view returns (uint256);
}
