// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILotteryExtension.sol";
import "./ILotteryStorage.sol";
import "./ILotteryCommon.sol";

interface ILottery is ILotteryStorage, ILotteryCommon {


    // --- External Functions ---
    // Liquidity management functions (restricted to owner in implementation)
    function depositLiquidity(uint256 amount) external;
    function requestWithdrawal(uint256 amount) external;
    function executeWithdrawal() external;

    // Commit-reveal function
    function addCommitment(bytes32 commitment) external;
    
    // Ticket purchase and reveal
    function purchaseTicket(string calldata userRandom) external returns (uint256 ticketId);
    function revealRandom(uint256 ticketId, string calldata reveal) external;
    function pendingMaxWinnings() external view returns (uint256);
    function getAvailableTickets() external view returns (uint256);
    
    // --- Solve Functions ---
    function solveMulmod15053(uint256 ticketId, uint256 x) external;
    function solveMulmod18015(uint256 ticketId, uint256 x) external;
    function solveMulmod19248(uint256 ticketId, uint256 x) external;
    function solveMulmod25536(uint256 ticketId, uint256 x) external;
    function solveMulmod28111(uint256 ticketId, uint256 x) external;
    function solveMulmod30726(uint256 ticketId, uint256 x) external;
    function solveMulmod34651(uint256 ticketId, uint256 x) external;
    function solveMulmod38257(uint256 ticketId, uint256 x) external;
    function solveMulmod44864(uint256 ticketId, uint256 x) external;
    function solveMulmod48351(uint256 ticketId, uint256 x) external;
    function solveMulmod53568(uint256 ticketId, uint256 x) external;
    function solveMulmod53604(uint256 ticketId, uint256 x) external;
    function solveMulmod61073(uint256 ticketId, uint256 x) external;
    function solveMulmod63592(uint256 ticketId, uint256 x) external;
    function solveMulmod68324(uint256 ticketId, uint256 x) external;
    function solveMulmod69175(uint256 ticketId, uint256 x) external;
    function solveMulmod72570(uint256 ticketId, uint256 x) external;
    function solveMulmod74676(uint256 ticketId, uint256 x) external;
    function solveMulmod77566(uint256 ticketId, uint256 x) external;
    function solveMulmod79137(uint256 ticketId, uint256 x) external;
    function solveMulmod79579(uint256 ticketId, uint256 x) external;
    function solveMulmod81474(uint256 ticketId, uint256 x) external;
    function solveMulmod82984(uint256 ticketId, uint256 x) external;
    function solveMulmod85887(uint256 ticketId, uint256 x) external;
    
    // --- Fallback ---
    fallback() external;
}
