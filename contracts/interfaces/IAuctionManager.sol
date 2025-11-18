// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./IAuctionVault.sol";
import "./IAuctionToken.sol";

interface IAuctionManager {
    // --- Structs ---
    struct Auction {
        address seller;
        IERC721 nftContract;
        uint256 tokenId;
        uint256 minPrice;
        uint256 askingPrice;
        IERC20 paymentToken;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool settled;
        bool isDutch;
    }

    // --- State Variable Getters ---
    function vault() external view returns (IAuctionVault);
    function auctionTokens(IERC20 underlying) external view returns (IAuctionToken);
    function lockedTokens(address account, IERC20 underlying) external view returns (uint256);
    function isTokenApproved(IERC20 underlying) external view returns (bool);
    function auctionCount() external view returns (uint256);
    function auctions(uint256 auctionId)
        external
        view
        returns (
            address seller,
            IERC721 nftContract,
            uint256 tokenId,
            uint256 minPrice,
            uint256 askingPrice,
            IERC20 paymentToken,
            uint256 startTime,
            uint256 endTime,
            address highestBidder,
            uint256 highestBid,
            bool settled,
            bool isDutch
        );
    function getCurrentPrice(uint256 auctionId) external view returns (uint256);

    // --- External Functions ---
    function registerAuctionToken(
        IERC20 underlying,
        string calldata name,
        string calldata symbol
    ) external;

    function approveToken(IERC20 underlying) external;

    function rescueTokens(IERC20 token, uint256 amount) external;

    function investInStrategy(IERC20 token, uint256 amount) external;

    function divestFromStrategy(IERC20 token, uint256 amount) external;
    
    function depositERC20(IERC20 underlying, uint256 amount) external;

    function withdrawERC20(IERC20 underlying, uint256 amount) external;

    function createAuction(
        IERC721 nftContract,
        uint256 tokenId,
        uint256 minPrice,
        uint256 askingPrice,
        IERC20 paymentToken,
        uint256 duration
    ) external returns (uint256 auctionId);

    function bid(uint256 auctionId, uint256 bidAmount) external;

    function settleAuction(uint256 auctionId) external;

    function createDutchAuction(
        IERC721 nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 minPrice,
        IERC20 paymentToken,
        uint256 duration
    ) external;

    function buy(uint256 auctionId) external;

    function cancelDutchAuction(uint256 auctionId) external;

    // --- Events ---
    event DepositERC20(address indexed user, IERC20 indexed token, uint256 amount);
    event WithdrawERC20(address indexed user, IERC20 indexed token, uint256 amount);
    event AuctionCreated(
        uint256 auctionId,
        address indexed seller,
        IERC721 nftContract,
        uint256 tokenId,
        uint256 minPrice,
        uint256 askingPrice,
        IERC20 paymentToken,
        uint256 startTime,
        uint256 endTime,
        bool isDutch
    );
    event NewBid(uint256 auctionId, address indexed bidder, uint256 bidAmount);
    event AuctionSettled(uint256 auctionId, address highestBidder, uint256 highestBid);
}
