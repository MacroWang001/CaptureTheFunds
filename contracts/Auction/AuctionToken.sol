// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./AuctionVault.sol";
import "../interfaces/IAuctionToken.sol";
import "../interfaces/IAuctionManager.sol";

contract AuctionToken is ERC20, Ownable, IAuctionToken {
    uint256 public constant BASE = 1e18;
    
    IERC20 public underlying;
    IAuctionVault public immutable vault;
    IAuctionManager public immutable auctionManager;

    constructor(
        string memory name_,
        string memory symbol_,
        IERC20 _underlying,
        IAuctionVault _vault,
        IAuctionManager _auctionManager
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        underlying = _underlying;
        vault = _vault;
        auctionManager = _auctionManager;
    }

    function currentScalingFactor() public view returns (uint256) {
        uint256 totalInternal = totalSupply();
        if (totalInternal == 0) {
            return BASE;
        }
        uint256 totalUnderlying = vault.getTotalUnderlying(underlying);
        return Math.mulDiv(totalUnderlying, BASE, totalInternal, Math.Rounding.Floor);
    }

    function balanceOf(address account) public view override(ERC20, IERC20) returns (uint256) {
        uint256 internalBalance = super.balanceOf(account);
        return (internalBalance * currentScalingFactor()) / BASE;
    }

    function mint(address to, uint256 externalAmount) external onlyOwner {
        uint256 factor = currentScalingFactor();
        uint256 internalAmount = Math.mulDiv(externalAmount, BASE, factor, Math.Rounding.Floor);
        _mint(to, internalAmount);
    }

    function burn(address from, uint256 externalAmount) external onlyOwner {
        uint256 factor = currentScalingFactor();
        uint256 internalAmount = Math.mulDiv(externalAmount, BASE, factor, Math.Rounding.Ceil);
        _burn(from, internalAmount);
    }

    function transfer(address to, uint256 externalAmount) public override(ERC20, IERC20) returns (bool) {
        uint256 factor = currentScalingFactor();
        uint256 internalAmount = Math.mulDiv(externalAmount, BASE, factor, Math.Rounding.Ceil);
        uint256 senderExternalBalance = balanceOf(_msgSender());
        uint256 locked = auctionManager.lockedTokens(_msgSender(), underlying);
        require(senderExternalBalance >= locked + externalAmount, "Transfer would reduce available balance below locked tokens");
        _transfer(_msgSender(), to, internalAmount);
        return true;
    }

    function transferFrom(address from, address to, uint256 externalAmount) public override(ERC20, IERC20) returns (bool) {
        uint256 factor = currentScalingFactor();
        uint256 internalAmount = Math.mulDiv(externalAmount, BASE, factor, Math.Rounding.Ceil);
        uint256 senderExternalBalance = balanceOf(from);
        uint256 locked = auctionManager.lockedTokens(from, underlying);
        require(senderExternalBalance >= locked + externalAmount, "Transfer would reduce available balance below locked tokens");
        if (owner() != _msgSender()) _spendAllowance(from, _msgSender(), internalAmount);
        _transfer(from, to, internalAmount);
        return true;
    }
}
