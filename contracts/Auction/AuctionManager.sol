// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AuctionVault.sol";
import "./AuctionToken.sol";
import "../interfaces/IAuctionManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract AuctionManager is ReentrancyGuard, Ownable, IAuctionManager {
    using SafeERC20 for IERC20;

    IAuctionVault public immutable vault;

    // Mapping from an underlying ERC20 to its corresponding AuctionToken.
    mapping(IERC20 => IAuctionToken) public auctionTokens;

    // Mapping tracking locked tokens for active bids.
    mapping(address => mapping(IERC20 => uint256)) public lockedTokens;

    // Mapping tracking tokens approved by the owner
    mapping(IERC20 => bool) public isTokenApproved;

    uint256 public auctionCount;
    mapping(uint256 => Auction) public auctions;

    
    constructor(address vaultAddress) Ownable(msg.sender) {
        vault = IAuctionVault(vaultAddress);
    }

    // Register a new auction token for a given underlying ERC20 token.
    function registerAuctionToken(IERC20 underlying, string memory name, string memory symbol) external {
        require(address(auctionTokens[underlying]) == address(0), "AuctionToken already exists");
        AuctionToken token = new AuctionToken(name, symbol, underlying, vault, IAuctionManager(address(this)));
        token.transferOwnership(address(this));
        auctionTokens[underlying] = token;
    }

    // Approve a token for use in the auction.
    function approveToken(IERC20 underlying) external onlyOwner {
        require(!isTokenApproved[underlying], "Token already approved");
        isTokenApproved[underlying] = true;
        vault.setApprovalForERC20(underlying);
    }

    // Rescue unregistered tokens
    function rescueTokens(IERC20 token, uint256 amount) external onlyOwner {
        require(address(auctionTokens[token]) == address(0), "Underlying token already registered");
        require(isTokenApproved[token], "Token needs to be approved");
        token.safeTransferFrom(address(vault), msg.sender, amount);
    }


    function investInStrategy(IERC20 token, uint256 amount) external onlyOwner {
        vault.invest(token, amount);
    }

    function divestFromStrategy(IERC20 token, uint256 amount) external onlyOwner {
        vault.divest(token, amount);
    }

    // Deposit underlying ERC20 token into the auction.
    function depositERC20(IERC20 underlying, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        IAuctionToken token = auctionTokens[underlying];
        require(address(token) != address(0), "AuctionToken not registered");
        token.mint(msg.sender, amount);
        underlying.safeTransferFrom(msg.sender, address(vault), amount);
        emit DepositERC20(msg.sender, underlying, amount);
    }

    // Withdraw underlying ERC20 token from the auction.
    function withdrawERC20(IERC20 underlying, uint256 amount) external nonReentrant {
        IAuctionToken token = auctionTokens[underlying];
        require(address(token) != address(0), "AuctionToken not registered");
        uint256 currentBalance = token.balanceOf(msg.sender);
        uint256 locked = lockedTokens[msg.sender][underlying];
        require(currentBalance >= locked + amount, "Not enough unlocked tokens");
        token.burn(msg.sender, amount);

        // Check vault's cash and divest from strategy if needed
        uint256 vaultCash = underlying.balanceOf(address(vault));
 
        if (vaultCash < amount) {
            uint256 deficit = amount - vaultCash;
            uint256 actualDivested = vault.divest(underlying, deficit);
            amount = vaultCash + actualDivested;
        }
        
        underlying.safeTransferFrom(address(vault), msg.sender, amount); 
        emit WithdrawERC20(msg.sender, underlying, amount);
    }

    // Create a new auction.
    function createAuction(
        IERC721 nftContract,
        uint256 tokenId,
        uint256 minPrice,
        uint256 askingPrice,
        IERC20 paymentToken,
        uint256 duration
    ) external nonReentrant returns (uint256 auctionId){
        require(duration > 0, "Duration must be > 0");
        require(askingPrice >= minPrice, "Asking price must be >= min price");
        require(isTokenApproved[paymentToken],"Payment token not approved");
        // Transfer the NFT to the vault
        nftContract.transferFrom(msg.sender, address(vault), tokenId);
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;
        auctionId = auctionCount;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            minPrice: minPrice,
            askingPrice: askingPrice,
            paymentToken: paymentToken,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            settled: false,
            isDutch: false
        });
        emit AuctionCreated(auctionCount, msg.sender, nftContract, tokenId, minPrice, askingPrice, paymentToken, startTime, endTime, false);
        auctionCount++;
    }

    // Bid on an auction.
    function bid(uint256 auctionId, uint256 bidAmount) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(!auction.isDutch, "Not a regular auction");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(bidAmount >= auction.minPrice, "Bid below minimum");
        require(bidAmount > auction.highestBid, "Bid not higher than current highest");

        IERC20 underlying = auction.paymentToken;
        IAuctionToken token = auctionTokens[underlying];
        require(address(token) != address(0), "AuctionToken not registered");

        uint256 currentBalance = token.balanceOf(msg.sender);
        uint256 currentlyLocked = lockedTokens[msg.sender][underlying];
        uint256 available = currentBalance > currentlyLocked ? currentBalance - currentlyLocked : 0;

        if (auction.highestBidder == msg.sender) {
            uint256 additionalRequired = bidAmount - auction.highestBid;
            require(available >= additionalRequired, "Not enough unlocked tokens for additional bid");
            lockedTokens[msg.sender][underlying] += additionalRequired;
            auction.highestBid = bidAmount;
        } else {
            require(available >= bidAmount, "Not enough unlocked tokens for bid");
            if (auction.highestBidder != address(0)) {
                lockedTokens[auction.highestBidder][underlying] -= auction.highestBid;
            }
            lockedTokens[msg.sender][underlying] += bidAmount;
            auction.highestBid = bidAmount;
            auction.highestBidder = msg.sender;
        }
        emit NewBid(auctionId, msg.sender, bidAmount);

        // If the bid is higher than the asking price, settle the auction.
        if (bidAmount >= auction.askingPrice) {
            auction.endTime = block.timestamp;
            _settleAuction(auctionId);
        }
    }

    function _settleAuction(uint256 auctionId) internal {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "Auction not ended");
        require(!auction.settled, "Auction already settled");

        auction.settled = true;
        IERC20 underlying = auction.paymentToken;
        IAuctionToken token = auctionTokens[underlying];

        // Approve AuctionManager for this NFT
        vault.setApprovalForNFT(auction.nftContract, auction.tokenId);

        if (auction.highestBidder != address(0)) {
            auction.nftContract.transferFrom(address(vault), auction.highestBidder, auction.tokenId);
            lockedTokens[auction.highestBidder][underlying] -= auction.highestBid;
            token.transferFrom(auction.highestBidder, auction.seller, auction.highestBid);
        } else {
            auction.nftContract.transferFrom(address(vault), auction.seller, auction.tokenId);
        }
        emit AuctionSettled(auctionId, auction.highestBidder, auction.highestBid);
    }

    // Settle an auction if it's already ended.
    function settleAuction(uint256 auctionId) external nonReentrant {
        _settleAuction(auctionId);
    }
    
    function createDutchAuction(
        IERC721 nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 minPrice,
        IERC20 paymentToken,
        uint256 duration
    ) external nonReentrant {
        require(duration > 0, "Duration must be > 0");
        require(startingPrice > minPrice, "Starting price must be greater than min price");
        require(isTokenApproved[paymentToken],"Payment token not approved");

        nftContract.transferFrom(msg.sender, address(vault), tokenId);
        vault.setApprovalForNFT(nftContract, tokenId);
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;
        auctions[auctionCount] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            minPrice: minPrice,
            askingPrice: startingPrice,
            paymentToken: paymentToken,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            settled: false,
            isDutch: true
        });
        emit AuctionCreated(auctionCount, msg.sender, nftContract, tokenId, minPrice, startingPrice, paymentToken, startTime, endTime, true);
        auctionCount++;
    }

    function getCurrentPrice(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        require(auction.isDutch, "Auction is not a Dutch auction");
        if (block.timestamp >= auction.endTime) {
            return auction.minPrice;
        } else {
            uint256 elapsed = block.timestamp - auction.startTime;
            uint256 duration = auction.endTime - auction.startTime;
            uint256 priceDiff = auction.askingPrice - auction.minPrice;
            return auction.askingPrice - ((priceDiff * elapsed) / duration);
        }
    }
    
    // Buy an NFT (Dutch auction only).
    function buy(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isDutch, "Not a Dutch auction");
        require(!auction.settled, "Auction already settled");
        
        uint256 currentPrice = getCurrentPrice(auctionId);
        
        auction.nftContract.transferFrom(address(vault), msg.sender, auction.tokenId);
        
        IAuctionToken token = auctionTokens[auction.paymentToken];
        require(address(token) != address(0), "AuctionToken not registered");
        token.transferFrom(msg.sender, auction.seller, currentPrice);
        
        auction.settled = true;
        auction.highestBidder = msg.sender;
        auction.highestBid = currentPrice;
        emit AuctionSettled(auctionId, msg.sender, currentPrice);
    }
    
    function cancelDutchAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isDutch, "Not a Dutch auction");
        require(!auction.settled, "Auction already settled");
        require(msg.sender == auction.seller, "Only seller can cancel");

        auction.settled = true;
        auction.nftContract.transferFrom(address(vault), auction.seller, auction.tokenId);
        emit AuctionSettled(auctionId, auction.seller, 0);
    }
}
