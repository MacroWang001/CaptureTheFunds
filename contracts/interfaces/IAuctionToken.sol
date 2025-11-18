// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IAuctionVault.sol";
import "./IAuctionManager.sol";

interface IAuctionToken is IERC20 {
    // --- State Variable Getters ---
    function BASE() external pure returns (uint256);
    function underlying() external view returns (IERC20);
    function vault() external view returns (IAuctionVault);
    function auctionManager() external view returns (IAuctionManager);

    // --- AuctionToken Specific Functions ---
    function currentScalingFactor() external view returns (uint256);
    function mint(address to, uint256 externalAmount) external;
    function burn(address from, uint256 externalAmount) external;
}
