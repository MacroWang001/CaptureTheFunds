// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IInvestmentVault.sol";
import "./IIdleMarket.sol";

/**
 * @title IInvestmentVaultFactory
 * @dev Interface for the InvestmentVaultFactory contract
 */
interface IInvestmentVaultFactory {
    // View functions
    function vaultsByAsset(IERC20 asset, uint256 index) external view returns (IInvestmentVault);
    function idleMarkets(IERC20 asset) external view returns (IIdleMarket);
    function protocolToAsset(IInvestmentVault vaultAddress) external view returns (IERC20);
    function getVaultsByAsset(IERC20 asset) external view returns (IInvestmentVault[] memory);
    
    // External functions
    function createInvestmentVault(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint256 initialDelay
    ) external returns (IInvestmentVault vaultAddress);
    
    
    // Events
    event InvestmentVaultCreated(IERC20 indexed asset, IInvestmentVault indexed vault);
    event IdleMarketCreated(IERC20 indexed asset, address idleMarket);
}

