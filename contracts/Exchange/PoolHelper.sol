// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IExchangeVault.sol";
import "../interfaces/IPool.sol";

contract PoolHelper {
    IExchangeVault public exchangeVault;

    constructor(address _exchangeVault) {
        exchangeVault = IExchangeVault(_exchangeVault);
    }

    function supplyLiquidity(
        IPool pool,
        uint256[] calldata amounts,
        address to
    ) external {
        // Get the pool's tokens from the ExchangeVault
        IERC20[] memory tokens = exchangeVault.getPoolTokens(pool);
        
        // Calculate and transfer the total amount needed for each token (including fees)
        for (uint256 i = 0; i < tokens.length; i++) {
            // Calculate fee: feeAmount = fee% of amounts[i]
            uint256 feeAmount = (amounts[i] * IExchangeVault(exchangeVault).fee()) / IExchangeVault(exchangeVault).PERCENT_DIVISOR();
            // Total amount needed is the amount plus the fee
            uint256 totalAmount = amounts[i] + feeAmount;
            
            // Check if the caller has enough balance
            require(tokens[i].balanceOf(msg.sender) >= totalAmount, "Insufficient token balance");
            
            // Transfer tokens from the caller to this contract
            require(tokens[i].transferFrom(msg.sender, address(this), totalAmount), "Transfer failed");
            
            // Approve ExchangeVault to spend the tokens
            require(tokens[i].approve(address(exchangeVault), totalAmount), "Approve failed");
        }

        // Encode the addLiquidityToPool call data
        bytes memory addLiquidityData = abi.encodeWithSignature(
            "addLiquidityToPool(address,uint256[],address)",
            pool,
            amounts,
            to
        );

        // Call unlock on the ExchangeVault with the encoded data
        exchangeVault.unlock(addLiquidityData);
    }

    function addLiquidityToPool(IPool pool, uint256[] calldata amounts, address to) external {
        // Get the pool's tokens from the ExchangeVault
        IERC20[] memory tokens = exchangeVault.getPoolTokens(pool);
        
        // Calculate and settle the total amount needed for each token (including fees)
        for (uint256 i = 0; i < tokens.length; i++) {
            // Calculate fee: feeAmount = fee% of amounts[i]
            uint256 feeAmount = (amounts[i] * exchangeVault.fee()) / exchangeVault.PERCENT_DIVISOR();
            // Total amount needed is the amount plus the fee
            uint256 totalAmount = amounts[i] + feeAmount;
            // Settle the tokens with the ExchangeVault
            exchangeVault.settle(tokens[i], totalAmount);
        }

        // Call addLiquidityToPool on the ExchangeVault
        exchangeVault.addLiquidityToPool(
            pool,
            amounts,
            to
        );
    }

    function swap(
        IPool pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address to
    ) external {

        uint256 feeAmount = (inputAmount * exchangeVault.fee()) / exchangeVault.PERCENT_DIVISOR();
        // Total amount needed is the amount plus the fee
        uint256 totalAmount = inputAmount + feeAmount;

        // Check if the caller has enough balance
        require(tokenIn.balanceOf(msg.sender) >= totalAmount, "Insufficient token balance");
            
        // Transfer tokens from the caller to this contract
        require(tokenIn.transferFrom(msg.sender, address(this), totalAmount), "Transfer failed");
            
        // Approve ExchangeVault to spend the tokens
        require(tokenIn.approve(address(exchangeVault), totalAmount), "Approve failed");

        // Encode the addLiquidityToPool call data
        bytes memory swapData = abi.encodeWithSignature(
            "swapInPoolCallback(address,address,address,uint256,uint256,uint256,address)",
            pool,
            tokenIn,
            tokenOut,
            inputAmount,
            totalAmount,
            minOutputAmount,
            to
        );

        // Call unlock on the ExchangeVault with the encoded data
        exchangeVault.unlock(swapData);
    }


    function swapInPoolCallback(IPool pool, IERC20 tokenIn, IERC20 tokenOut, uint256 inputAmount, uint256 totalAmount, uint256 minOutputAmount, address to) external {
        exchangeVault.settle(tokenIn, totalAmount);

        // Call swapInPool on the ExchangeVault
        uint256 outputAmount = exchangeVault.swapInPool(
            pool,
            tokenIn,
            tokenOut,
            inputAmount,
            minOutputAmount
        );
        require(outputAmount >= minOutputAmount);

        exchangeVault.sendTo(tokenOut, to, outputAmount);
    }
}