// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILotteryStorage {
    // --- Public Variables / Getters ---
    function usdc() external view returns (IERC20);
    function ticketPrice() external view returns (uint256);
    
    // Constants as external pure functions.
    function MAX_RANDOM() external pure returns (uint256);
    function MAX_SKILL() external pure returns (uint256);
    function MAX_WINNING() external pure returns (uint256);
    function REDEEM_DELAY() external pure returns (uint256);

    // Mapping getter for tickets: index => Ticket fields.
    // Note: Solidity auto-generated getters for structs return each field in order.
    function tickets(uint256 index)
        external
        view
        returns (
            uint256 id,
            uint256 purchaseTime,
            uint256 expirationTime,
            bool redeemed,
            string memory userRandom,
            bytes32 commitment,
            bool revealed,
            uint256 randomComponent,
            uint256 revealDeadline
        );

    function nextTicketId() external view returns (uint256);

    // Array getter for commitments.
    function commitments(uint256 index) external view returns (bytes32);

    function nextCommitIndex() external view returns (uint256);

    // Liquidity management variables.
    function liquidity() external view returns (uint256);
    function pendingWithdrawalAmount() external view returns (uint256);
    function withdrawalRequestTime() external view returns (uint256);
    function withdrawalRequested() external view returns (bool);
}
