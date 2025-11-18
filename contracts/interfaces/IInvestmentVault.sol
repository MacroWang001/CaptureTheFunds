// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "./IIdleMarket.sol";

/**
 * @title IInvestmentVault
 * @dev Interface for the InvestmentVault contract
 */
interface IInvestmentVault is IERC4626 {

    struct PendingChange {
        uint256 value;
        uint256 validAt; // timestamp at which change can be accepted
    }

    struct MarketInfo {
        uint256 cap; // maximum asset amount that can be invested in this market (0 means no deposits allowed)
        bool enabled;
        uint256 pendingRemovalTimestamp; // if nonzero, removal is pending until this timestamp
    }

    struct MarketAllocation {
        IERC4626 market;
        uint256 assets; // desired total assets to be held in this market after reallocation
    }

    // ----------------------------------
    // State variable getters (public)
    // ----------------------------------
    function DEC_OFFSET() external view returns (uint8);
    function WAD() external pure returns (uint256);
    function MIN_DELAY() external pure returns (uint256);
    function MAX_DELAY() external pure returns (uint256);
    function delay() external view returns (uint256);
    function pendingDelay() external view returns (uint256 value, uint256 validAt);
    function markets(uint256 index) external view returns (IERC4626);
    function getMarkets() external view returns (IERC4626[] memory);
    function marketInfo(IERC4626 market) external view returns (uint256 cap, bool enabled, uint256 pendingRemovalTimestamp);
    function pendingMarketAddition(IERC4626 market) external view returns (uint256 value, uint256 validAt);
    function pendingMarketLimit(IERC4626 market) external view returns (uint256 value, uint256 validAt);
    function idleMarket() external view returns (IIdleMarket);

    // ----------------------------------
    // External functions
    // ----------------------------------


    function submitMarketAddition(IERC4626 market, uint256 cap) external;
    function acceptMarketAddition(IERC4626 market) external;
    function submitMarketRemoval(IERC4626 market) external;
    function acceptMarketRemoval(IERC4626 market) external;
    function submitMarketLimitUpdate(IERC4626 market, uint256 newCap) external;
    function acceptMarketLimitUpdate(IERC4626 market) external;
    function submitDelayChange(uint256 newDelay) external;
    function acceptDelayChange() external;
    function marketBalance(IERC4626 market) external view returns (uint256 assets, uint256 shares);
    function reallocate(MarketAllocation[] calldata allocations) external;

    // ----------------------------------
    // Events
    // ----------------------------------
    event MarketAdditionSubmitted(IERC4626 indexed market, uint256 cap, uint256 validAt);
    event MarketAdditionAccepted(IERC4626 indexed market, uint256 cap);
    event MarketRemovalSubmitted(IERC4626 indexed market, uint256 validAt);
    event MarketRemovalAccepted(IERC4626 indexed market);
    event MarketLimitUpdateSubmitted(IERC4626 indexed market, uint256 newCap, uint256 validAt);
    event MarketLimitUpdateAccepted(IERC4626 indexed market, uint256 newCap);
    event DelayChangeSubmitted(uint256 newDelay, uint256 validAt);
    event DelayChangeAccepted(uint256 newDelay);
    event MarketReallocatedDeposit(IERC4626 indexed market, uint256 deposited);
    event MarketReallocatedWithdraw(IERC4626 indexed market, uint256 withdrawn);
} 