// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IIdleMarket.sol";


/**
 * @title IdleMarket
 * @notice An ERC4626 Market that uses internal accounting for its asset balance,
 * offers flashloans (with a fee), and restricts deposits/withdrawals to InvestmentMarkets
 * created via the factory. Instead of maintaining its own authorized mappings,
 * it checks that the asset in the factory's protocolToAsset mapping matches its own underlying asset.
 */
contract IdleMarket is
    ERC4626,
    Ownable,
    ReentrancyGuard, 
    IIdleMarket
{
    using Math for uint256;

    // --------------------------------------------------------------------------------
    // Storage
    // --------------------------------------------------------------------------------

    // Internal accounting variable for total assets.
    uint256 private _totalAssetsInternal;

    // Flashloan fee expressed in basis points (e.g. 50 means 0.5%).
    uint256 public flashloanFee;

    // Address of the InvestmentMarketFactory.
    IInvestmentVaultFactory public immutable factory;

    // --------------------------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------------------------

    /**
     * @notice Checks if an account is an authorized Investment protocol.
     * @param account The address to check authorization for.
     * @return True if authorized, false otherwise.
     */
    function _isAuthorizedProtocol(address account) private view returns (bool) {
        return address(factory.protocolToAsset(IInvestmentVault(account))) == asset();
    }

    /**
     * @notice Ensures that only authorized Investment protocols can interact.
     * @param account The address to verify (typically msg.sender or a function parameter).
     */
    modifier onlyAuthorizedProtocol(address account) {
        require(_isAuthorizedProtocol(account), "Not authorized");
        _;
    }

    // --------------------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------------------

    /**
     * @notice Constructor to initialize the IdleMarket.
     * @param _owner   The owner of the market.
     * @param _factory The InvestmentMarketFactory address.
     * @param _asset   The underlying asset.
     * @param _name    The name of the IdleMarket token.
     * @param _symbol  The symbol of the IdleMarket token.
     */
    constructor(
        address _owner,
        address _factory,
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) 
        ERC4626(_asset)
        ERC20(_name, _symbol)
        Ownable(_owner)
    {
        require(_factory != address(0), "Factory address zero");

        // Set factory and internal asset accounting
        factory = IInvestmentVaultFactory(_factory);
        _totalAssetsInternal = _asset.balanceOf(address(this));
    }

    // --------------------------------------------------------------------------------
    // Overrides
    // --------------------------------------------------------------------------------

    /**
     * @notice Overrides ERC4626.totalAssets() to return the internal accounting value.
     */
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        return _totalAssetsInternal;
    }

    /**
     * @notice Allows the owner to set the flashloan fee.
     * For example, if set to 50 then fee = 0.5% (plus an extra 1 wei).
     */
    function setFlashloanFee(uint256 _fee) external onlyOwner {
        flashloanFee = _fee;
    }

    // --- Restrict deposit/mint/withdraw/redeem to authorized Investment protocols ---

    function maxDeposit(address depositor) public view override(ERC4626, IERC4626) returns (uint256) {
        if (!_isAuthorizedProtocol(depositor)) return 0;
        return super.maxDeposit(depositor);
    }

    function maxMint(address depositor) public view override(ERC4626, IERC4626) returns (uint256) {
        if (!_isAuthorizedProtocol(depositor)) return 0;
        return super.maxMint(depositor);
    }

    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626, IERC4626)
        onlyAuthorizedProtocol(msg.sender)
        nonReentrant        
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);
        _totalAssetsInternal += assets;
    }

    function mint(uint256 shares, address receiver)
        public
        override(ERC4626, IERC4626)
        onlyAuthorizedProtocol(msg.sender)
        nonReentrant        
        returns (uint256 assets)
    {
        assets = super.mint(shares, receiver);
        _totalAssetsInternal += assets;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IERC4626)
        onlyAuthorizedProtocol(msg.sender)
        nonReentrant        
        returns (uint256 shares)
    {
        shares = super.withdraw(assets, receiver, owner);
        _totalAssetsInternal = _zeroFloorSub(_totalAssetsInternal, assets);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626, IERC4626)
        onlyAuthorizedProtocol(msg.sender)
        nonReentrant        
        returns (uint256 assets)
    {
        assets = super.redeem(shares, receiver, owner);
        _totalAssetsInternal = _zeroFloorSub(_totalAssetsInternal, assets);
    }

    // --------------------------------------------------------------------------------
    // Flashloan Functionality
    // --------------------------------------------------------------------------------

    /**
     * @notice Offers a flashloan to any caller.
     * The borrower must return the funds plus the flashloan fee in the same transaction.
     * Fee = (amount * flashloanFee / 10000) + 1 wei.
     */
    function flashloan(uint256 amount, address receiver, bytes calldata data)
        external
        nonReentrant
    {
        uint256 initialBalance = IERC20(asset()).balanceOf(address(this));
        require(initialBalance >= amount, "Not enough liquidity");

        // Transfer out the flashloan.
        IERC20(asset()).transfer(receiver, amount);

        // Invoke callback on the receiver.
        // Invoke callback on the receiver and bubble up revert reasons.
        (bool success, bytes memory returnData) = receiver.call(data);
        if (!success) {
            // Bubble up the revert reason if available
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("IdleMarket -Flashloan callback failed with no reason");
            }
        }

        // Calculate fee
        // Like in  FlashLoaner.sol
        uint256 feeAmount = (amount * flashloanFee) / 10000 + 1;
        uint256 finalBalance = IERC20(asset()).balanceOf(address(this));
        require(finalBalance >= initialBalance + feeAmount, "Flashloan not repaid with fee");

        // Update internal accounting with the fee.
        _totalAssetsInternal += feeAmount;

        emit FlashloanExecuted(msg.sender, amount, feeAmount);
    }

    // --------------------------------------------------------------------------------
    // Internal Utility
    // --------------------------------------------------------------------------------

    function _zeroFloorSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }
}
