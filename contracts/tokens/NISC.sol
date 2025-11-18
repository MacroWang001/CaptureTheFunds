// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NISC - New International Stable Currency
 * @notice Backed by NIS
 */

contract NISC is ERC20, Ownable {
    constructor() ERC20("New International Stable Currency", "NISC") Ownable(msg.sender) {}

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

    /**
     * @dev Override to skip self-transfers (gas optimization)
     */
    function _update(address from, address to, uint256 value) internal override {
        if (from == to) {
            return;
        }
        super._update(from, to, value);
    }
}
