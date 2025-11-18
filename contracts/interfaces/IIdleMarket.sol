// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "./IInvestmentVaultFactory.sol";

/**
 * @title IIdleMarket
 * @dev Interface for the IdleMarket contract
 */
interface IIdleMarket is IERC4626 {
    // ----------------------------------
    // State variable getters (public)
    // ----------------------------------
    function flashloanFee() external view returns (uint256);
    function factory() external view returns (IInvestmentVaultFactory);


    // ----------------------------------
    // External functions
    // ----------------------------------
    function setFlashloanFee(uint256 _fee) external;
    function flashloan(uint256 amount, address receiver, bytes calldata data) external;

    // ----------------------------------
    // Events
    // ----------------------------------
    event FlashloanExecuted(address indexed receiver, uint256 amount, uint256 fee);
    
} 