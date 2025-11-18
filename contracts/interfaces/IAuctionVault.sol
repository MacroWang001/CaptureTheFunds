
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./IStrategy.sol"; // Assumes you have an IStrategy interface
import "./IAuctionManager.sol";
/**
 * @title IAuctionVault
 * @dev Interface for the AuctionVault contract.
 */
interface IAuctionVault is IERC721Receiver {
    // --- State Getters ---
    function auctionManager() external view returns (IAuctionManager);
    function currentStrategy() external view returns (IStrategy);
    function pendingStrategy() external view returns (IStrategy);
    function strategyTimelock() external view returns (uint256);
    function TIMELOCK_DURATION() external pure returns (uint256);

    // --- External Functions ---
    function setAuctionManager(IAuctionManager _auctionManager) external;
    function proposeStrategy(IStrategy _newStrategy) external;
    function updateStrategy() external;
    function setApprovalForERC20(IERC20 token) external;
    function setApprovalForNFT(IERC721 nftContract, uint256 tokenId) external;
    function getTotalUnderlying(IERC20 token) external view returns (uint256);
    function invest(IERC20 token, uint256 amount) external;
    function divest(IERC20 token, uint256 amount) external returns (uint256);

    // --- Events ---
    event StrategyChangeProposed(IStrategy newStrategy, uint256 timelock);
    event StrategyChanged(IStrategy newStrategy);
    event FundsInvested(IERC20 indexed token, uint256 amount);
    event FundsDivested(IERC20 indexed token, uint256 amount);
}
