// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IExchange {
    // --- State Getters ---
    function usdc() external view returns (IERC20);
    function RATE() external pure returns (uint256);

    // --- External Functions ---
    function swapETHforUSDC() external payable;
    function swapUSDCforETH(uint256 usdcAmount) external;

    // The receive function is declared so the contract can accept ETH.
    receive() external payable;
}
