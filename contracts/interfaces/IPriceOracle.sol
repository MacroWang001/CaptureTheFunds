// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IPriceOracle
 * @notice Minimal price oracle interface.
 * Prices are returned in 1e18 precision.
 * For example, if an asset is worth USD 2.00, the oracle returns 2e18.
 */
interface IPriceOracle {
    /**
     * @notice Owner-only: set or update the price of `asset`.
     * @param asset  The token address (non‑zero).
     * @param price  The price in 1e18 units (must be > 0).
     */
    function setPrice(IERC20 asset, uint256 price) external;

    /**
     * @notice Returns the price of `asset` in 1e18 precision.
     * @param asset  The token address.
     * @return       The price in 1e18 units.
     */
    function getPrice(IERC20 asset) external view returns (uint256);

    // --- Events ---
    event PriceSet(IERC20 indexed asset, uint256 price);
}
