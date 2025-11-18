// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILendingManager.sol";
import "./ILendingPool.sol";
import "./IPriceOracle.sol";
import "./IFlashLoaner.sol";

interface ILendingFactory {
     // Grouped asset parameters
    struct AssetInfo {
        IERC20 assetA;
        IERC20 assetB;
        string nameA;
        string symbolA;
        string nameB;
        string symbolB;
    }
    // Grouped rate parameters
    struct RateInfo {
        uint256 rateMin;
        uint256 rateOptimal;
        uint256 rateMax;
        uint256 utilOptimal;
    }
    // Grouped policy parameters
    struct PolicyInfo {
        uint256 LTV;
        uint256 LT;
    }
    // Grouped fee parameters
    struct FeeInfo {
        address feeBeneficiary;
        uint256 feePercentage;
    }
    // Trio information
    struct Trio {
        ILendingManager lendingManager;
        ILendingPool poolA;
        ILendingPool poolB;
    }
    // --- State Variable Getters ---
    
    /// @notice Returns the address of the central flash loan contract.
    function flashLoaner() external view returns (IFlashLoaner);
    
    /// @notice Returns the trio at a given index.
    function trios(uint256 index) external view returns (
        ILendingManager lendingManager,
        ILendingPool poolA,
        ILendingPool poolB
    );

    // --- View functions ---

    /// @notice Returns the number of lending trios.
    function getTrioCount() external view returns (uint256);

    /// @notice Returns the lending manager and lending pools at a given index.
    function getTrio(uint256 index) external view returns (
        ILendingManager lendingManager,
        ILendingPool poolA,
        ILendingPool poolB
    );

    // --- Admin functions ---

    /// @notice Sets the centralized FlashLoaner contract.
    function setFlashLoaner(address flashLoaner_) external;

    /// @notice Removes a lending trio by index.
    function removeTrio(uint256 index) external;

    /// @notice Creates a new lending trio with provided parameters.
    function createTrio(
        AssetInfo memory assetInfo,
        RateInfo memory rateInfo,
        PolicyInfo memory policyInfo,
        FeeInfo memory feeInfo,
        IPriceOracle priceOracle
    ) external returns (
        ILendingManager lendingManager,
        ILendingPool poolA,
        ILendingPool poolB
    );


    // --- Events ---

    event TrioCreated(ILendingManager indexed lendingManager, ILendingPool poolA, ILendingPool poolB);
    event TrioRemoved(uint256 index, ILendingManager indexed lendingManager, ILendingPool poolA, ILendingPool poolB);
}
