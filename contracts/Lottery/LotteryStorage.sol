// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ILotteryStorage.sol";

abstract contract LotteryStorage is ILotteryStorage {
    // USDC token address (assumed to have 6 decimals)
    IERC20 public usdc;
    // Ticket price: 200,000 USDC.
    uint256 public ticketPrice;
    uint256 public constant MAX_RANDOM = 250_000 * 10 ** 6;
    uint256 public constant MAX_SKILL  = 100_000 * 10 ** 6;
    uint256 public constant MAX_WINNING = MAX_RANDOM + MAX_SKILL; // 350,000 USDC

    // Redemption delay: 1 day after purchase.
    uint256 public constant REDEEM_DELAY = 1 days;

    // Each ticket is represented as an NFT. This struct stores its gameplay and timing data.
    struct Ticket {
        uint256 id;
        uint256 purchaseTime;
        uint256 expirationTime; // purchaseTime + 2 days.
        bool redeemed;
        string userRandom;      // Provided by the ticket buyer.
        bytes32 commitment;     // Owner's precommitted hash.
        bool revealed;          // Whether the owner has revealed.
        uint256 randomComponent;// Base prize (random component).
        uint256 revealDeadline; // purchaseTime + 1 day.
    }
    mapping(uint256 => Ticket) public tickets;
    uint256 public nextTicketId;

    // Owner's commit queue.
    bytes32[] public commitments;
    uint256 public nextCommitIndex;

    // Liquidity: includes ticket payments and owner deposits.
    uint256 public liquidity;
    uint256 public pendingWithdrawalAmount;
    uint256 public withdrawalRequestTime;
    bool public withdrawalRequested;
    
    // Track which challenges have been solved
    mapping(uint256 => bool) public solvedChallenges;
}
