// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; 
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IAuctionVault.sol";
import "../interfaces/IStrategy.sol";

contract AuctionVault is IERC721Receiver, Ownable, IAuctionVault {
    using SafeERC20 for IERC20;

    IAuctionManager public auctionManager;
    IStrategy public currentStrategy;
    IStrategy public pendingStrategy;
    uint256 public strategyTimelock;
    uint256 public constant TIMELOCK_DURATION = 1 days;

    modifier onlyAuctionManager() {
        require(msg.sender == address(auctionManager), "AV: Caller is not the AuctionManager");
        _;
    }

    constructor(IStrategy _defaultStrategy)
        Ownable(msg.sender)
    {
        currentStrategy = _defaultStrategy;
    }

    // Setter for auctionManager (deployment convenience)
    function setAuctionManager(IAuctionManager _auctionManager) external onlyOwner {
        require(address(auctionManager) == address(0), "Auction Manager already set");
        auctionManager = _auctionManager;
    }

    function proposeStrategy(IStrategy _newStrategy) external onlyOwner {
        pendingStrategy = _newStrategy;
        strategyTimelock = block.timestamp + TIMELOCK_DURATION;
        emit StrategyChangeProposed(_newStrategy, strategyTimelock);
    }

    function updateStrategy() external onlyOwner {
        require(address(pendingStrategy) != address(0), "No strategy proposed");
        require(block.timestamp >= strategyTimelock, "Timelock not expired");
        currentStrategy = pendingStrategy;
        pendingStrategy = IStrategy(address(0));
        strategyTimelock = 0;
        emit StrategyChanged(currentStrategy);
    }

    function setApprovalForERC20(IERC20 token) external onlyAuctionManager {
        token.forceApprove(address(auctionManager), type(uint256).max);
    }
    
    function setApprovalForNFT(IERC721 nftContract, uint256 tokenId) external onlyAuctionManager {
        nftContract.approve(address(auctionManager), tokenId);
    }

    function getTotalUnderlying(IERC20 token) external view returns (uint256) {
        uint256 vaultBalance = token.balanceOf(address(this));
        if (address(currentStrategy) != address(0)) {
            uint256 strategyBalance = currentStrategy.getBalance(token);
            return vaultBalance + strategyBalance;
        }
        return vaultBalance;
    }

    function invest(IERC20 token, uint256 amount) external onlyAuctionManager {
        require(amount > 0, "AV: Amount must be > 0");
        uint256 vaultBalance = token.balanceOf(address(this));
        require(vaultBalance >= amount, "AV: Insufficient vault balance");
        
        // Approve strategy to spend tokens
        token.approve(address(currentStrategy), amount);
        
        // Invest in strategy
        currentStrategy.invest(token, amount);
        emit FundsInvested(token, amount);
    }

    function divest(IERC20 token, uint256 amount) external onlyAuctionManager returns (uint256) {
        require(amount > 0, "AV: Amount must be > 0");
        uint256 strategyBalance = currentStrategy.getBalance(token);
        require(strategyBalance >= amount, "AV: Insufficient strategy balance");
        
        // Divest from strategy and get actual amount received
        uint256 actualReceived = currentStrategy.divest(token, amount);
        emit FundsDivested(token, actualReceived);
        return actualReceived;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
