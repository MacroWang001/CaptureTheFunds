// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import {IPool} from "../interfaces/IPool.sol";
import "../interfaces/IExchangeVault.sol";

library SafeCast {
    /**
     * @dev Converts a uint256 to an int256 in an unchecked way.
     * Reverts if the value cannot be safely converted to an int256.
     */
    function toInt256(uint256 value) internal pure returns (int256 result) {
        assembly {
            let max := shl(255, 1)
            if gt(value, max) { revert(0, 0) }
            result := value
        }
    }

    /**
     * @dev Converts an int256 to a uint256.
     * Reverts if the int256 is negative.
     */
    function toUint256(int256 value) internal pure returns (uint256 result) {
        assembly {
            if slt(value, 0) { revert(0, 0) }
            result := value
        }
    }
}


contract ExchangeVault is IExchangeVault {
    using SafeCast for *;

    // Fee related state.
    address public feeRecipient;
    // Fee in basis points (e.g., 2 means 0.02%). Fees are charged on deposits.
    uint256 public fee;
    uint256 public constant PERCENT_DIVISOR = 10000;
    // Maximum fee allowed is 0.1% (10 basis points).
    uint256 public constant MAX_FEE = 10;
    mapping(IERC20 => uint256) public accruedFees;

    // Underlying token accounting: a positive delta indicates debt (vault owes tokens), negative indicates surplus.
    mapping(IERC20 => int256) private _tokenDeltas;

    bool private _unlocked;
    uint256 private _nonZeroDeltaCount;
    bool private _locked;


    mapping(IPool => Pool) public pools;
    mapping(IPool => bool) public isPoolRegistered;

    // Underlying balances per pool: pool address => (token => balance)
    mapping(IPool => mapping(IERC20 => uint256)) public poolBalances;

    // LP token balances and allowances per pool.
    mapping(IPool => mapping(address => uint256)) private _poolLPBalances;
    mapping(IPool => mapping(address => mapping(address => uint256))) private _lpAllowances;

    uint256 public globalSwapFee;

    modifier nonReentrant() {
        require(!_locked, "Reentrant");
        _locked = true;
        _;
        _locked = false;
    }
    modifier onlyWhenUnlocked() {
        require(_unlocked, "Vault is not unlocked");
        _;
    }
    modifier transient() {
        bool wasUnlocked = _unlocked;
        if (!wasUnlocked) { _unlocked = true; }
        _;
        if (!wasUnlocked) {
            require(_nonZeroDeltaCount == 0, "Balance not settled");
            _unlocked = false;
        }
    }

    constructor(address _feeRecipient, uint256 _fee) payable {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
        require(_fee <= MAX_FEE, "Fee too high");
        fee = _fee;
    }

    /// @notice Allows the feeRecipient to update the fee.
    /// @param newFee The new fee in basis points (must be <= 0.1% or 10 basis points).
    function setFee(uint256 newFee) external {
        require(msg.sender == feeRecipient, "Only feeRecipient can set fee");
        require(newFee <= MAX_FEE, "Fee exceeds maximum");
        fee = newFee;
    }

    // External fund transfer functions.
    function settle(IERC20 token, uint256 credit)
        external
        nonReentrant
        onlyWhenUnlocked
        returns (uint256)
    {
        require(token.transferFrom(msg.sender, address(this), credit), "Transfer failed");
        _supplyCredit(token, credit);
        return credit;
    }

    function sendTo(IERC20 token, address to, uint256 amount)
        external
        nonReentrant
        onlyWhenUnlocked
    {
        _takeDebt(token, amount);
        require(token.transfer(to, amount), "Transfer failed");
    }

    // Pool registration.
    function registerPool(IPool pool, IERC20[] calldata tokens) external {
        require(address(pool) != address(0), "Invalid pool");
        require(!isPoolRegistered[pool], "Pool already registered");
        uint256 len = tokens.length;
        require(len > 0, "No tokens provided");
        for (uint256 i = 1; i < len; i++) {
            require(address(tokens[i - 1]) < address(tokens[i]), "Tokens not sorted");
        }
        Pool storage p = pools[pool];
        p.totalSupply = 0;
        p.tokens = new IERC20[](len);
        for (uint256 i = 0; i < len; i++) {
            p.tokens[i] = tokens[i];
            poolBalances[pool][tokens[i]] = 0;
        }
        isPoolRegistered[pool] = true;
    }

    // Liquidity management.
    function addLiquidityToPool(
        IPool pool,
        uint256[] calldata amounts,
        address to
    ) external nonReentrant onlyWhenUnlocked {
        require(isPoolRegistered[pool], "Pool not registered");
        Pool storage p = pools[pool];
        uint256 len = p.tokens.length;
        require(amounts.length == len, "Amounts length mismatch");

        uint256[] memory currentBalances = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            currentBalances[i] = poolBalances[pool][p.tokens[i]];
            // Compute fee: feeAmount = fee% of amounts[i].
            uint256 feeAmount = (amounts[i] * fee) / PERCENT_DIVISOR;
            // The user must supply the net amount plus the fee.
            _takeDebt(p.tokens[i], amounts[i] + feeAmount);
            // Only the net amount goes to the pool.
            poolBalances[pool][p.tokens[i]] += amounts[i];
            // Record the fee for later redemption.
            accruedFees[p.tokens[i]] += feeAmount;
        }

        uint256 lpMint = pool.calculateLiquidityAddition(currentBalances, amounts, p.totalSupply);
        
        _mintTokens(pool, to, lpMint);
    }

    function removeLiquidityFromPool(
        IPool pool,
        uint256 lpAmount,
        address from
    ) external nonReentrant onlyWhenUnlocked {
        require(isPoolRegistered[pool], "Pool not registered");
        Pool storage p = pools[pool];
        require(_poolLPBalances[pool][from] >= lpAmount, "Insufficient LP tokens");

        uint256[] memory currentBalances = new uint256[](p.tokens.length);
        for (uint256 i = 0; i < p.tokens.length; i++) {
            currentBalances[i] = poolBalances[pool][p.tokens[i]];
        }

        uint256[] memory amountsOut = pool.calculateLiquidityRemoval(currentBalances, lpAmount, p.totalSupply);
        uint256 len = amountsOut.length;
        for (uint256 i = 0; i < len; i++) {
            _supplyCredit(p.tokens[i], amountsOut[i]);
            poolBalances[pool][p.tokens[i]] = currentBalances[i] - amountsOut[i];
        }
        _burnTokens(pool, from, lpAmount);
    }
    function getPoolTokens(IPool pool) external view returns (IERC20[] memory) {
        require(isPoolRegistered[pool], "Pool not registered");
        return pools[pool].tokens;
    }

    function swapInPool(
        IPool pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 inputAmount,
        uint256 minOutputAmount
    ) external nonReentrant onlyWhenUnlocked returns (uint256 outputAmount) {
        require(isPoolRegistered[pool], "Pool not registered");
        Pool storage p = pools[pool];

        uint256[] memory currentBalances = new uint256[](p.tokens.length);
        for (uint256 i = 0; i < p.tokens.length; i++) {
            currentBalances[i] = poolBalances[pool][p.tokens[i]];
        }

        // For swaps, charge a fee on top of the input amount.
        uint256 feeAmount = (inputAmount * fee) / PERCENT_DIVISOR;
        // The vault now expects to receive the full input plus fee from the user.
        _takeDebt(tokenIn, inputAmount + feeAmount);
        // The pool receives the full input amount.
        poolBalances[pool][tokenIn] += inputAmount;

        // Compute the swap output based on the full input amount.
        outputAmount = pool.computeSwapAmount(currentBalances, inputAmount, tokenIn, tokenOut);
        require(outputAmount >= minOutputAmount, "Slippage");

        poolBalances[pool][tokenOut] -= outputAmount;
        // For tokenOut, the vault reduces its obligation since tokens are going out.
        _supplyCredit(tokenOut, outputAmount);

        // Record the fee for later redemption.
        accruedFees[tokenIn] += feeAmount;
    }

    // Internal LP token functions.
    function _mintTokens(IPool pool, address to, uint256 amount) internal {
        _poolLPBalances[pool][to] += amount;
        pools[pool].totalSupply += amount;
        emit LPMinted(pool, to, amount);
    }
    function _burnTokens(IPool pool, address from, uint256 amount) internal {
        require(_poolLPBalances[pool][from] >= amount, "Insufficient LP tokens");
        _poolLPBalances[pool][from] -= amount;
        pools[pool].totalSupply -= amount;
        emit LPBurned(pool, from, amount);
    }

    // ERC20-like LP token functions.
    function totalSupply(IPool pool) external view returns (uint256) {
        require(isPoolRegistered[pool], "Pool not registered");
        return pools[pool].totalSupply;
    }
    function balanceOf(IPool pool, address account) external view returns (uint256) {
        return _poolLPBalances[pool][account];
    }
    function allowance(IPool pool, address owner, address spender) external view returns (uint256) {
        return _lpAllowances[pool][owner][spender];
    }
    function approve(IPool pool, address spender, uint256 amount) external returns (bool) {
        _lpAllowances[pool][msg.sender][spender] = amount;
        emit LPApproval(pool, msg.sender, spender, amount);
        return true;
    }
    function transfer(IPool pool, address to, uint256 amount) external returns (bool) {
        require(_poolLPBalances[pool][msg.sender] >= amount, "Insufficient LP tokens");
        _poolLPBalances[pool][msg.sender] -= amount;
        _poolLPBalances[pool][to] += amount;
        emit LPTransfer(pool, msg.sender, to, amount);
        return true;
    }
    function transferFrom(IPool pool, address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _lpAllowances[pool][from][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");
        _lpAllowances[pool][from][msg.sender] = currentAllowance - amount;
        require(_poolLPBalances[pool][from] >= amount, "Insufficient LP tokens");
        _poolLPBalances[pool][from] -= amount;
        _poolLPBalances[pool][to] += amount;
        emit LPTransfer(pool, from, to, amount);
        return true;
    }

    // Modified unlock function to bubble up underlying revert reasons.
    function unlock(bytes calldata data)
        external
        transient
        returns (bytes memory result)
    {
        (bool success, bytes memory returnData) = msg.sender.call(data);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Exchange Vault - External call failed with no reason");
            }
        }
        result = returnData;
    }

    function tokenDelta(IERC20 token) external view returns (int256) {
        return _tokenDeltas[token];
    }


    function _supplyCredit(IERC20 token, uint256 credit) internal {
        _accountDelta(token, -SafeCast.toInt256(credit));
    }
    function _takeDebt(IERC20 token, uint256 debt) internal {
        _accountDelta(token, SafeCast.toInt256(debt));
    }
    function _accountDelta(IERC20 token, int256 delta) internal {
        if (delta == 0) return;
        int256 current = _tokenDeltas[token];
        int256 next = current + delta;
        if (current == 0 && next != 0) {
            _nonZeroDeltaCount++;
        } else if (current != 0 && next == 0) {
            _nonZeroDeltaCount--;
        }
        _tokenDeltas[token] = next;
    }
    
    // Function for feeRecipient to redeem accrued fees for a token.
    function redeemFees(IERC20 token, uint256 amount) external {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(accruedFees[token] >= amount, "Insufficient accrued fees");
        accruedFees[token] -= amount;
        require(token.transfer(feeRecipient, amount), "Transfer failed");
    }
}
