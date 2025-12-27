
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IAuctionManager.sol";
import "./interfaces/IAuctionToken.sol";
import "./interfaces/IAuctionVault.sol";
import "./interfaces/ICommunityInsurance.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IExchangeVault.sol";
import "./interfaces/IFlashLoaner.sol";
import "./interfaces/IIdleMarket.sol";
import "./interfaces/IInvestmentVault.sol";
import "./interfaces/IInvestmentVaultFactory.sol";
import "./interfaces/ILendingFactory.sol";
import "./interfaces/ILendingManager.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILottery.sol";
import "./interfaces/ILotteryCommon.sol";
import "./interfaces/ILotteryExtension.sol";
import "./interfaces/ILotteryStorage.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IWeth.sol";

contract AttackContract {
    IERC20 public constant usdc = IERC20(0xBf1C7F6f838DeF75F1c47e9b6D3885937F899B7C);
    IERC20 public constant nisc = IERC20(0x20e4c056400C6c5292aBe187F832E63B257e6f23);
    IWeth public constant weth = IWeth(0x13d78a4653e4E18886FBE116FbB9065f1B55Cd1d);
    ILottery public constant lottery = ILottery(0x6D03B9e06ED6B7bCF5bf1CF59E63B6eCA45c103d);
    ILotteryExtension public constant lotteryExtension = ILotteryExtension(0x6D03B9e06ED6B7bCF5bf1CF59E63B6eCA45c103d);
    IAuctionVault public constant auctionVault = IAuctionVault(0x9f4a3Ba629EF680c211871c712053A65aEe463B0);
    IAuctionManager public constant auctionManager = IAuctionManager(0x228F0e62b49d2b395Ee004E3ff06841B21AA0B54);
    IStrategy public constant lendingPoolStrategy = IStrategy(0xC5cBC10e8C7424e38D45341bD31342838334dA55);
    IExchangeVault public constant exchangeVault = IExchangeVault(0x776B51e76150de6D50B06fD0Bd045de0a13D68C7);
    // Product pools: [0] = USDC/WETH pool, [1] = USDC/NISC pool
    IPool[] public productPools = [IPool(0x536BF770397157efF236647d7299696B90Bc95f1), IPool(0x6cAC85Dc0D547225351097Fb9eEb33D65978bb73)];
    IPriceOracle public constant priceOracle = IPriceOracle(0x9231ffAC09999D682dD2d837a5ac9458045Ba1b8);
    ILendingFactory public constant lendingFactory = ILendingFactory(0xdC5b6f8971AD22dC9d68ed7fB18fE2DB4eC66791);
    // Lending managers: [0] = Lending Trio 1 manager, [1] = Lending Trio 2 manager
    ILendingManager[] public lendingManagers = [ILendingManager(0x66bf9ECb0B63dC4815Ab1D2844bE0E06aB506D4f), ILendingManager(0x5FdA5021562A2Bdfa68688d1DFAEEb2203d8d045)];
    ILendingPool[] public lendingPoolsA = [ILendingPool(0xfAC23E673e77f76c8B90c018c33e061aE8F8CBD9), ILendingPool(0xFa6c040D3e2D5fEB86Eda9e22736BbC6eA81a16b)];
    ILendingPool[] public lendingPoolsB = [ILendingPool(0xb022AE7701DF829F2FF14B51a6DFC8c9A95c6C61), ILendingPool(0x537B309Fec55AD15Ef2dFae1f6eF3AEBD80d0d9c)];
    IFlashLoaner public constant flashLoaner = IFlashLoaner(0x5861a917A5f78857868D88Bd93A18A3Df8E9baC7);
    IInvestmentVaultFactory public constant investmentFactory = IInvestmentVaultFactory(0xd526270308228fDc16079Bd28eB1aBcaDd278fbD);
    IIdleMarket public constant usdcIdleMarket = IIdleMarket(0xB926534D703B249B586A818B23710938D40a1746);
    // Investment vaults: [0] = USDC Strategy 1 vault, [1] = USDC Strategy 2 vault
    IInvestmentVault[] public investmentVaults = [IInvestmentVault(0x99828D8000e5D8186624263f1b4267aFD4E27669), IInvestmentVault(0xe7A23A3Bf899f67e0B40809C8f449A7882f1a26E)];
    ICommunityInsurance public constant communityInsurance = ICommunityInsurance(0x83f3997529982fB89C4c983D82d8d0eEAb2Bb034);
    IRewardDistributor public constant rewardDistributor = IRewardDistributor(0x73a8004bCD026481e27b5B7D0d48edE428891995);
    
    /// STORAGE
    

    
