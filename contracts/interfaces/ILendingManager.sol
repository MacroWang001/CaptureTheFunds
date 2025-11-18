// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPriceOracle.sol";
import "./ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for LendingManager
/// @notice Exposes all external methods and events of the LendingManager contract
interface ILendingManager {

     /// @notice Enum to identify which asset (A or B) is being operated on
    enum AssetType { A, B }
    
    /// @notice Struct to store position data for a user
    struct Position {
        uint256 collateralAShares;
        uint256 normalizedBorrowB;
        uint256 collateralBShares;
        uint256 normalizedBorrowA;
    }
    /// @notice Struct to group pool and asset data for easier access
    struct PoolInfo {
        ILendingPool pool;
        IERC20 asset;
        address[] debtors;
        mapping(address => bool) isDebtor;
    }
    // --- View variables ---
    function poolA() external view returns (ILendingPool);
    function poolB() external view returns (ILendingPool);
    function assetA() external view returns (IERC20);
    function assetB() external view returns (IERC20);
    function LTV() external view returns (uint256);
    function LT() external view returns (uint256);
    function priceOracle() external view returns (IPriceOracle);
    function poolsSet() external view returns (bool);
    function MIN_COLLATERAL_USD() external view returns (uint256);
    function debtorsA(uint256 index) external view returns (address);
    function debtorsB(uint256 index) external view returns (address);
    // --- Position and Debt Views ---
    function positions(address user)
        external
        view
        returns (
            uint256 collateralAShares,
            uint256 normalizedBorrowB,
            uint256 collateralBShares,
            uint256 normalizedBorrowA
        );

    function isDebtorA(address user) external view returns (bool);
    function isDebtorB(address user) external view returns (bool);

    // --- Updated API with AssetType ---
    // Get debt amount for the given asset type
    function getDebt(AssetType assetType, address user) external view returns (uint256 actualDebt);

    // Check if a position can be liquidated for given asset type
    function canLiquidate(AssetType assetType, address target) external view returns (bool);
    
    // Check if a position has bad debt for given asset type
    function isBadDebt(AssetType assetType, address target) external view returns (bool);

    // Get all liquidatable positions for given asset type
    function getLiquidatable(AssetType assetType)
        external
        view
        returns (
            address[] memory users,
            uint256[] memory collateralShares,
            uint256[] memory debtAmounts
        );

    // --- Lifecycle ---
    function setPools(ILendingPool poolA_, ILendingPool poolB_) external;

    // --- Collateral ---
    function lockCollateral(AssetType assetType, uint256 shares) external;
    function unlockCollateral(AssetType assetType, uint256 shares) external;

    // --- Borrowing ---
    function borrow(AssetType assetType, uint256 amount) external;
    function repay(AssetType assetType, uint256 amount) external;

    // --- Liquidation ---
    function liquidate(AssetType assetType, address target) external returns (uint256 collateralShares);

    // --- Events ---
    event LockedCollateral(address indexed user, IERC20 indexed asset, uint256 shares);
    event UnlockedCollateral(address indexed user, IERC20 indexed asset, uint256 shares);
    event Borrowed(address indexed user, IERC20 indexed asset, uint256 amount);
    event Repaid(address indexed user, IERC20 indexed asset, uint256 amount);
    event Liquidation(
        address indexed liquidator,
        address indexed target,
        IERC20 debtAsset,
        uint256 debtRepaid,
        IERC20 collateralAsset,
        uint256 collateralSeized
    );
}
