// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

interface IPool {
    
    function calculateLiquidityAddition(
        uint256[] calldata currentBalances,
        uint256[] calldata amountsSupplied,
        uint256 lpTotalSupply
    ) external view returns (uint256 lpMint);

    function calculateLiquidityRemoval(
        uint256[] calldata currentBalances,
        uint256 lpAmount,
        uint256 lpTotalSupply
    ) external view returns (uint256[] memory amountsOut);

    function computeSwapAmount(
        uint256[] calldata currentBalances,
        uint256 inputAmount,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) external view returns (uint256 outputAmount);

    function poolName() external view returns (string memory);
}
