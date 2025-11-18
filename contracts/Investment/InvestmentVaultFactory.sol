// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../interfaces/IInvestmentVault.sol";
import "../interfaces/IIdleMarket.sol";
import "../interfaces/IInvestmentVaultFactory.sol";
import "./IdleMarket.sol";
import "./InvestmentVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract InvestmentVaultFactory is Ownable, IInvestmentVaultFactory {
    // Mapping from asset address to an array of InvestmentVault addresses.
    mapping(IERC20 => IInvestmentVault[]) public vaultsByAsset;
    // Mapping from asset address to its single IdleMarket.
    mapping(IERC20 => IIdleMarket) public idleMarkets;
    // Mapping from InvestmentVault (protocol) to its asset.
    mapping(IInvestmentVault => IERC20) public protocolToAsset;

    constructor() Ownable(msg.sender) {}
    
    /// @notice Creates a new InvestmentVault instance for a given asset.
    /// If an IdleMarket for the asset already exists, it will be used.
    /// @param asset The underlying asset for the vault.
    /// @param name The name of the InvestmentVault token.
    /// @param symbol The symbol of the InvestmentVault token.
    /// @param initialDelay The initial delay for timelocked operations.
    function createInvestmentVault(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint256 initialDelay
    ) external returns (IInvestmentVault investmentVault) {
        require(address(asset) != address(0), "Invalid asset address");

        IIdleMarket idleMarket;
        // Check if an IdleMarket for this asset already exists.
        if (address(idleMarkets[asset]) == address(0)) {
            // Derive a dynamic name & symbol from the underlying token
            string memory assetSym   = IERC20Metadata(address(asset)).symbol();
            string memory idleName   = string.concat("Idle Market ", assetSym);
            string memory idleSymbol = string.concat("IDLE-",      assetSym);

            idleMarket = new IdleMarket(owner(),address(this),asset,idleName,idleSymbol);
            idleMarkets[asset] = idleMarket;
            
            emit IdleMarketCreated(asset, address(idleMarket));
        } else {
            idleMarket = idleMarkets[asset];
        }

        investmentVault = new InvestmentVault(owner(),initialDelay,asset,name,symbol,idleMarket); 
        vaultsByAsset[asset].push(investmentVault);
        protocolToAsset[investmentVault] = asset;
        emit InvestmentVaultCreated(asset, investmentVault);
    }
    /// @notice Returns the list of InvestmentVaults for a given asset.
    function getVaultsByAsset(IERC20 asset) external view returns (IInvestmentVault[] memory) {
        return vaultsByAsset[asset];
    }
}
