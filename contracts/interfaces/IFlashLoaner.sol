// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILendingPool.sol";
import "./ILendingFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoaner {
    struct PoolWithdrawal {
        ILendingPool pool;
        uint256 withdrawnAmount;
    }

    // --- State Variable Getters ---
    function factory() external view returns (ILendingFactory);
    function flashloanFee() external view returns (uint256);
    function flashloanFeeRecipient() external view returns (address);
    function accruedFees(IERC20 asset) external view returns (uint256);

    // --- External Functions ---
    function getMaxFlashLoanAmount(IERC20 asset) external view returns (uint256);
    function flashloan(
        IERC20 asset,
        uint256 amount,
        address receiver,
        bytes calldata data
    ) external;
    function withdrawFees(IERC20 asset) external;
}
interface IFlashLoanReceiver {
        function onCallback(bytes calldata data) external;
    }