// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {
    function invest(IERC20 token, uint256 amount) external;
    function divest(IERC20 token, uint256 amount) external returns (uint256);
    function getBalance(IERC20 token) external view returns (uint256);
}