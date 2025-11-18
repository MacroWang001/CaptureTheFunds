// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceOracle
 * @notice A simple price oracle where the owner can set and update arbitrary asset prices.
 * Prices are expressed in 1e18 precision (e.g. 1 USDC = 1e18).
 */
contract PriceOracle is Ownable, IPriceOracle {
    /// @dev asset ⇒ price (in 1e18)
    mapping(IERC20 => uint256) private prices;

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Owner call only: set or update the price of `asset`.
     * @param asset  The ERC‑20 token address (must be non‑zero).
     * @param price  The asset’s price in 1e18 units (must be >0).
     */
    function setPrice(IERC20 asset, uint256 price) external onlyOwner {
        require(address(asset) != address(0), "PriceOracle: invalid asset");
        require(price > 0,            "PriceOracle: invalid price");
        prices[asset] = price;
        emit PriceSet(asset, price);
    }

    /**
     * @notice Returns the price of `asset` in 1e18 precision.
     * @dev Reverts if no price has been set for `asset`.
     * @param asset  The ERC‑20 token address.
     * @return       The price in 1e18 units.
     */
    function getPrice(IERC20 asset) external view returns (uint256) {
        uint256 p = prices[asset];
        require(p != 0, "PriceOracle: price not set");
        return p;
    }
}
