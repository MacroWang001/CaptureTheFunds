// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "./IPool.sol";
/**
 * @title IExchangeVault
 * @dev Interface for the ExchangeVault contract
 */
interface IExchangeVault {

    // Pool information: each pool stores its token set and its LP total supply.
    struct Pool {
        IERC20[] tokens;
        uint256 totalSupply; // LP token total supply for the pool.
    }

    // ----------------------------------
    // State variable getters (public)
    // ----------------------------------
    function feeRecipient() external view returns (address);
    function fee() external view returns (uint256);
    function globalSwapFee() external view returns (uint256);

    // Constants are typically not re-declared in interfaces,
    // but if you need them as view functions:
    function PERCENT_DIVISOR() external pure returns (uint256);
    function MAX_FEE() external pure returns (uint256);

    // Mappings: public => auto-generated getter
    function accruedFees(IERC20 token) external view returns (uint256);
    function isPoolRegistered(IPool pool) external view returns (bool);

    // Each pool stores tokens[] and totalSupply in a struct.
    // The struct can't be returned directly, but you can expose partial getters:
    // E.g. totalSupply() is already a separate function below.
    // For tokens[], you'd need a function like "getPoolTokens(pool)" if you want it in the interface.
    function getPoolTokens(IPool pool) external view returns (IERC20[] memory);

    function poolBalances(IPool pool, IERC20 token) external view returns (uint256);

    // Standard "LP token" balance and allowance tracking
    function totalSupply(IPool pool) external view returns (uint256);
    function balanceOf(IPool pool, address account) external view returns (uint256);
    function allowance(IPool pool, address owner, address spender) external view returns (uint256);

    // Deltas and session management
    function tokenDelta(IERC20 token) external view returns (int256);

    // ----------------------------------
    // External functions
    // ----------------------------------
    function setFee(uint256 newFee) external;

    function settle(IERC20 token, uint256 credit)
        external
        returns (uint256);

    function sendTo(IERC20 token, address to, uint256 amount) external;

    function registerPool(IPool pool, IERC20[] calldata tokens) external;

    function addLiquidityToPool(
        IPool pool,
        uint256[] calldata amounts,
        address to
    ) external;

    function removeLiquidityFromPool(
        IPool pool,
        uint256 lpAmount,
        address from
    ) external;

    function swapInPool(
        IPool pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 inputAmount,
        uint256 minOutputAmount
    ) external returns (uint256 outputAmount);

    // ERC20-like LP token functions
    function approve(IPool pool, address spender, uint256 amount) external returns (bool);
    function transfer(IPool pool, address to, uint256 amount) external returns (bool);
    function transferFrom(IPool pool, address from, address to, uint256 amount) external returns (bool);

    // Unlock function
    function unlock(bytes calldata data) external returns (bytes memory result);

    // Fee redemption
    function redeemFees(IERC20 token, uint256 amount) external;

    // ----------------------------------
    // Events
    // ----------------------------------
    event LPMinted(IPool indexed pool, address indexed to, uint256 amount);
    event LPBurned(IPool indexed pool, address indexed from, uint256 amount);
    event LPTransfer(IPool indexed pool, address indexed from, address indexed to, uint256 amount);
    event LPApproval(IPool indexed pool, address indexed owner, address indexed spender, uint256 amount);
}
