// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import {IPool} from "../interfaces/IPool.sol";

/// @title ProductPool
/// @notice A basic constant product pool supporting 2 tokens. It implements the IPool interface.
/// The pool uses the invariant x * y = k. For liquidity additions:
/// - If the pool is empty, initial liquidity minted is sqrt(amount0 * amount1).
/// - Otherwise, liquidity minted is proportional to the supplied amounts relative to current balances.
/// For removals, output amounts are proportional to the liquidity burned.
/// Swap amounts are computed using the invariant formula.
contract ProductPool is IPool {
    IERC20 public token0;
    IERC20 public token1;
    string public poolName;

    /// @notice Constructor sets the underlying tokens and a human‑readable pool name.
    /// @param _token0 The address of token0. Must be lower than token1.
    /// @param _token1 The address of token1.
    /// @param _poolName The name of the pool (e.g. "WETH/USDC Pool").
    constructor(IERC20 _token0, IERC20 _token1, string memory _poolName) {
        require(address(_token0) < address(_token1), "Tokens not sorted");
        token0 = _token0;
        token1 = _token1;
        poolName = _poolName;
    }
    
    /// @notice Calculates LP tokens to mint given current balances and supplied amounts.
    /// @dev For an empty pool, lpMint = sqrt(amount0 * amount1). Otherwise, lpMint = min(amount0 * lpTotalSupply / balance0, amount1 * lpTotalSupply / balance1).
    function calculateLiquidityAddition(
        uint256[] calldata currentBalances,
        uint256[] calldata amountsSupplied,
        uint256 lpTotalSupply
    ) external pure override returns (uint256 lpMint) {
        require(currentBalances.length == 2 && amountsSupplied.length == 2, "Invalid input length");
        uint256 balance0 = currentBalances[0];
        uint256 balance1 = currentBalances[1];
        uint256 amount0 = amountsSupplied[0];
        uint256 amount1 = amountsSupplied[1];
        if (balance0 == 0 && balance1 == 0) {
            lpMint = _sqrt(amount0 * amount1);
        } else {
            require(balance0 > 0 && balance1 > 0, "Non-zero balances required");
            uint256 liquidity0 = (amount0 * lpTotalSupply) / balance0;
            uint256 liquidity1 = (amount1 * lpTotalSupply) / balance1;
            lpMint = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
    }
    
    /// @notice Calculates output amounts for liquidity removal given current balances and LP tokens burned.
    function calculateLiquidityRemoval(
        uint256[] calldata currentBalances,
        uint256 lpAmount,
        uint256 lpTotalSupply
    ) external pure override returns (uint256[] memory amountsOut) {
        require(currentBalances.length == 2, "Invalid input length");
        amountsOut = new uint256[](2);
        uint256 balance0 = currentBalances[0];
        uint256 balance1 = currentBalances[1];
        require(lpTotalSupply > 0, "No liquidity");
        amountsOut[0] = (lpAmount * balance0) / lpTotalSupply;
        amountsOut[1] = (lpAmount * balance1) / lpTotalSupply;
    }
    
    /// @notice Computes the swap output amount based on the constant product invariant.
    /// @dev For tokenIn == token0 and tokenOut == token1, output = balance1 - (invariant / (balance0 + inputAmount)).
    function computeSwapAmount(
        uint256[] calldata currentBalances,
        uint256 inputAmount,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) external view override returns (uint256 outputAmount) {
        require(currentBalances.length == 2, "Invalid input length");
        uint256 balance0 = currentBalances[0];
        uint256 balance1 = currentBalances[1];
        if (tokenIn == token0 && tokenOut == token1) {
            uint256 newBalance0 = balance0 + inputAmount;
            uint256 invariant = balance0 * balance1;
            uint256 newBalance1 = invariant / newBalance0;
            outputAmount = balance1 > newBalance1 ? balance1 - newBalance1 : 0;
        } else if (tokenIn == token1 && tokenOut == token0) {
            uint256 newBalance1 = balance1 + inputAmount;
            uint256 invariant = balance0 * balance1;
            uint256 newBalance0 = invariant / newBalance1;
            outputAmount = balance0 > newBalance0 ? balance0 - newBalance0 : 0;
        } else {
            revert("Invalid token pair");
        }
    }
    
   
    /// @dev Internal function to compute square root using the Babylonian method.
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
