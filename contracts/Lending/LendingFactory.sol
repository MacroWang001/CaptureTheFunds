// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ILendingFactory.sol";
import "./LendingManager.sol";
import "./LendingPool.sol";

/**
 * @title LendingFactory
 * @notice This factory deploys isolated lending trios.
 * Only the owner can create or remove trios.
 */
contract LendingFactory is Ownable, ILendingFactory {
    // Centralized FlashLoaner address; must be set by the owner.
    IFlashLoaner public flashLoaner;

    Trio[] public trios;


    constructor() Ownable(msg.sender) {
    }

    /// @notice Sets the centralized FlashLoaner contract.
    function setFlashLoaner(address _flashLoaner) external onlyOwner {
        require(_flashLoaner != address(0), "LendingFactory: Invalid flashloan contract address");
        flashLoaner = IFlashLoaner(_flashLoaner);
    }

    /**
     * @notice Creates a new lending trio.
     * @param assetInfo Grouped asset parameters.
     * @param rateInfo Grouped rate parameters.
     * @param policyInfo Grouped lending policy parameters.
     * @param feeInfo Grouped fee parameters.
     * @param priceOracle The address of the price oracle.
     */
    function createTrio(
        AssetInfo memory assetInfo,
        RateInfo memory rateInfo,
        PolicyInfo memory policyInfo,
        FeeInfo memory feeInfo,
        IPriceOracle priceOracle
    )
        external
        onlyOwner
        returns (ILendingManager, ILendingPool, ILendingPool)
    {
        require(address(flashLoaner) != address(0),"LendingFactory: FlashLoaner not set");
        // Validate inputs
        _validateTrioParams(rateInfo, policyInfo, feeInfo);
        
        ILendingManager lendingManager = new LendingManager(priceOracle,policyInfo.LTV,policyInfo.LT);
        
        ILendingPool poolA = 
            new LendingPool(
                assetInfo.assetA,
                assetInfo.nameA,
                assetInfo.symbolA,
                rateInfo.rateMin,
                rateInfo.rateOptimal,
                rateInfo.rateMax,
                rateInfo.utilOptimal,
                lendingManager,
                feeInfo.feeBeneficiary,
                feeInfo.feePercentage,
                flashLoaner
            );
        
        ILendingPool poolB = 
            new LendingPool(
                assetInfo.assetB,
                assetInfo.nameB,
                assetInfo.symbolB,
                rateInfo.rateMin,
                rateInfo.rateOptimal,
                rateInfo.rateMax,
                rateInfo.utilOptimal,
                lendingManager,
                feeInfo.feeBeneficiary,
                feeInfo.feePercentage,
                flashLoaner
            );
        
        lendingManager.setPools(poolA, poolB);
        trios.push(Trio(lendingManager, poolA, poolB));

        emit TrioCreated(lendingManager, poolA, poolB);
        
        // Return the addresses
        return (lendingManager, poolA, poolB);
    }
    
    /**
     * @notice Validates the parameters for creating a trio
     */
    function _validateTrioParams(
        RateInfo memory rateInfo,
        PolicyInfo memory policyInfo,
        FeeInfo memory feeInfo
    ) private view {
        require(rateInfo.rateMax >= rateInfo.rateOptimal && rateInfo.rateOptimal >= rateInfo.rateMin, "LendingFactory: Rate ordering invalid");
        require(rateInfo.utilOptimal >= 0 && rateInfo.utilOptimal < 1e18, "LendingFactory: Invalid utilOptimal");
        require(policyInfo.LTV > 0 && policyInfo.LTV < policyInfo.LT, "LendingFactory: LTV must be >0 and < LT");
        require(feeInfo.feePercentage <= 2e16, "LendingFactory: Fee exceeds 2%");
        require(address(flashLoaner) != address(0), "LendingFactory: FlashLoaner not set");
    }
    
    

    /**
     * @notice Removes a trio using swap-and-pop.
     * @param index The index of the trio to remove.
     */
    function removeTrio(uint256 index) external onlyOwner {
        require(index < trios.length, "LendingFactory: Index out of range");
        Trio memory removed = trios[index];
        trios[index] = trios[trios.length - 1];
        trios.pop();
        emit TrioRemoved(index, removed.lendingManager, removed.poolA, removed.poolB);
    }

    /**
     * @notice Returns the number of lending trios.
     */
    function getTrioCount() external view returns (uint256) {
        return trios.length;
    }

    /**
     * @notice Returns a specific trio at the given index.
     */
    function getTrio(uint256 index) external view returns (ILendingManager lendingManager, ILendingPool poolA, ILendingPool poolB) {
        require(index < trios.length, "LendingFactory: Index out of range");
        Trio memory trio = trios[index];
        return (trio.lendingManager, trio.poolA, trio.poolB);
    }
}