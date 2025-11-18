// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IAuctionVault.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingPoolStrategy is IStrategy, Ownable {
    using SafeERC20 for IERC20;

    ILendingPool public immutable lendingPool;
    IAuctionVault public auctionVault;
    
    mapping(IERC20 => uint256) public shares;
    
    modifier onlyAuctionVault() {
        require(msg.sender == address(auctionVault), "LPS: Caller is not the AuctionVault");
        _;
    }

    constructor(ILendingPool _lendingPool) Ownable(msg.sender) {
        lendingPool = _lendingPool;
    }

    function setAuctionVault(address _vault) external onlyOwner {
        require(address(auctionVault) == address(0), "LPS: AuctionVault already set");
        auctionVault = IAuctionVault(_vault);
    }
    
    function invest(IERC20 token, uint256 amount) external override onlyAuctionVault {
        require(address(token) == address(lendingPool.asset()), "Token not supported by lending pool");
        
        // Note: The strategy now pulls funds directly from the vault,
        // which must have approved the strategy beforehand.
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve lending pool to spend tokens
        token.approve(address(lendingPool), amount);
        
        // Deposit into lending pool
        uint256 sharesReceived = lendingPool.deposit(amount, address(this));
        
        // Track shares
        shares[token] += sharesReceived;
    }
    
    function divest(IERC20 token, uint256 amount) external override onlyAuctionVault returns (uint256) {
        require(address(token) == address(lendingPool.asset()), "Token not supported by lending pool");
        require(shares[token] > 0, "No shares to withdraw");
        
        // Get balance before withdrawal
        uint256 balanceBefore = token.balanceOf(address(this));
        
        // Calculate how many shares we need to redeem to get the requested amount
        uint256 sharesToRedeem = lendingPool.convertToShares(amount);
        require(sharesToRedeem <= shares[token], "Insufficient shares");
        
        // Redeem shares from lending pool
        lendingPool.redeem(sharesToRedeem, address(this), address(this));
        
        // Calculate actual assets received (handles ERC4626 rounding)
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        
        // Update share balance
        shares[token] -= sharesToRedeem;
        
        // Transfer actual received tokens back to vault (msg.sender)
        token.safeTransfer(msg.sender, actualReceived);
        
        // Return the actual amount divested
        return actualReceived;
    }
    
    function getBalance(IERC20 token) external view override returns (uint256) {
        if (address(token) != address(lendingPool.asset()) || shares[token] == 0) {
            return 0;
        }
        
        // Convert shares to underlying assets
        return lendingPool.convertToAssets(shares[token]);
    }
}
