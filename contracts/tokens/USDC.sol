// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title USDC - United States Dollar Certora
 * @notice Backed by USD
 */

contract USDC is ERC20, Ownable {
    uint8 private _decimals;
    constructor() ERC20("USD Certora", "USDC") Ownable(msg.sender) {
        _decimals = 6;
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mints `amount` tokens to `to`. Callable only by owner.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burns `amount` tokens from `from`. Callable only by owner.
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
