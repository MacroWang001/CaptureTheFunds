// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IFlashLoaner.sol";
import "../interfaces/ILendingFactory.sol";
import "../interfaces/ILendingPool.sol";
/**
 * @title FlashLoaner
 * @notice Centralized flashloan contract that aggregates liquidity from all LendingPools
 * registered in the factory for a given asset, sends a flashloan to a receiver, and then returns
 * the exact tokens withdrawn to the pools. The fee (set on the FlashLoaner) is retained and forwarded
 * to the designated fee recipient at the end.
 */
contract FlashLoaner is Ownable, IFlashLoaner {
    using SafeERC20 for IERC20;

    ILendingFactory public factory;

    // Flashloan fee in basis points (e.g. 50 means 0.5%).
    uint256 public flashloanFee;
    // Recipient address for the flashloan fee.
    address public flashloanFeeRecipient;

    // Mapping to store accrued fees per asset.
    mapping(IERC20 => uint256) public accruedFees;

    modifier onlyFeeRecipient() {
        require(msg.sender == flashloanFeeRecipient, "FlashLoaner: Caller is not the fee recipient");
        _;
    }

    constructor(ILendingFactory _factory, uint256 _flashloanFee, address _flashloanFeeRecipient) Ownable(msg.sender) {
        require(_flashloanFeeRecipient != address(0), "FlashLoaner: Invalid fee recipient");
        factory = _factory;
        flashloanFee = _flashloanFee;
        flashloanFeeRecipient = _flashloanFeeRecipient;
    }

    /**
     * @notice Executes a flashloan.
     * @param asset The ERC20 asset to borrow.
     * @param amount The requested borrow amount.
     * @param receiver The address that will receive the funds.
     * @param data Arbitrary data passed to the receiver's callback.
     */
    function flashloan(
        IERC20 asset,
        uint256 amount,
        address receiver,
        bytes calldata data
    ) external {
        uint256 trioCount = factory.getTrioCount();
        uint256 totalWithdrawn = 0;
        // Maximum number of pools is two per trio.
        PoolWithdrawal[] memory withdrawals = new PoolWithdrawal[](2 * trioCount);
        uint256 wIndex = 0;

        // Withdraw available liquidity from each LendingPool that holds the requested asset.
        for (uint256 i = 0; i < trioCount && totalWithdrawn < amount; i++) {
            ( , ILendingPool poolA, ILendingPool poolB) = factory.getTrio(i);
            
            
            if (address(poolA.asset()) == address(asset)) {
                uint256 poolCash = poolA.getCash();
                if (poolCash > 0) {
                    uint256 amountToGet = amount - totalWithdrawn;
                    uint256 toWithdraw = (amountToGet < poolCash) ? amountToGet : poolCash;
                    uint256 withdrawn = poolA.flashloanWithdraw(toWithdraw);
                    totalWithdrawn += withdrawn;
                    withdrawals[wIndex] = PoolWithdrawal({pool: poolA, withdrawnAmount: withdrawn});
                    wIndex++;
                }
            }
            
            if (totalWithdrawn < amount) {
                if (address(poolB.asset()) == address(asset)) {
                    uint256 poolCash = poolB.getCash();
                     if (poolCash > 0) {
                        uint256 amountToGet = amount - totalWithdrawn;
                        uint256 toWithdraw = (amountToGet < poolCash) ? amountToGet : poolCash;
                        uint256 withdrawn = poolB.flashloanWithdraw(toWithdraw);
                        totalWithdrawn += withdrawn;
                        withdrawals[wIndex] = PoolWithdrawal({pool: poolB, withdrawnAmount: withdrawn});
                        wIndex++;
                    }
                }
            }
        }

        require(totalWithdrawn >= amount, "FlashLoaner: Insufficient liquidity");

        IERC20 token = asset;
        // The contract should start with zero balance for this asset.
        uint256 initialBalance = token.balanceOf(address(this));

        // Add 1 wei instead of rounding up. It’s preferable for the user to slightly overpay to avoid rounding logic and reduce gas overhead.
        uint256 fee = (amount * flashloanFee) / 10000 + 1;
        // Transfer the requested amount to the receiver.
        token.safeTransfer(receiver, amount);

        // Execute the callback on the receiver.
        try IFlashLoanReceiver(receiver).onCallback(data){

        } catch Error(string memory reason) {
            revert(string.concat("FlashLoanReceiver callback failed: ", reason));
        } catch (bytes memory lowLevelData) {
            assembly {
                let returndata_size := mload(lowLevelData)
                revert(add(lowLevelData, 32), returndata_size)
            }
        }

        // After callback, the contract must have recovered at least its original balance plus the fee.
        require(token.balanceOf(address(this)) >= initialBalance + fee, "FlashLoaner: Insufficient repayment");

        // Return the originally withdrawn tokens to each pool.
        for (uint256 j = 0; j < wIndex; j++) {
            // Transfer tokens back to the pool.
            token.safeTransfer(address(withdrawals[j].pool), withdrawals[j].withdrawnAmount);
            // Update the pool's internal accounting.
            withdrawals[j].pool.flashloanReturn(withdrawals[j].withdrawnAmount);
        }

        // Any leftover tokens (the fee) are added to the accrued fees for the recipient to claim.
        uint256 feeBalance = token.balanceOf(address(this));
        if (feeBalance > 0) {
            accruedFees[asset] += feeBalance;
        }
    }
    /// @notice Calculate the maximum amount of tokens that can be flash loaned
    /// @param asset The address of the token to flash loan
    /// @return maxAmount The maximum amount of tokens that can be flash loaned
    function getMaxFlashLoanAmount(IERC20 asset) external view returns (uint256 maxAmount) {

        uint256 trioCount = factory.getTrioCount();
        
        // Iterate through all lending pools to sum up available liquidity
        for (uint256 i = 0; i < trioCount; i++) {
            ( , ILendingPool poolA, ILendingPool poolB) = factory.getTrio(i);
            
            if (address(poolA.asset()) == address(asset)) {
                maxAmount += poolA.getCash();
            }
            if (address(poolB.asset()) == address(asset)) {
                maxAmount += poolB.getCash();
            }
        }
        
        return maxAmount;
    }

    /// @notice Withdraws the accrued fees for a specific asset.
    /// @param asset The address of the token for which to withdraw fees.
    function withdrawFees(IERC20 asset) external onlyFeeRecipient {
        uint256 fees = accruedFees[asset];
        require(fees > 0, "FlashLoaner: No fees to withdraw");
        accruedFees[asset] = 0;
        asset.safeTransfer(flashloanFeeRecipient, fees);
    }
}
