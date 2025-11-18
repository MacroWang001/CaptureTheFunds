// File: RewardDistributor.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICommunityInsurance.sol";
import "../interfaces/IRewardDistributor.sol";
/**
 * @title RewardDistributor
 * @notice Accrues rewards per second for CommunityInsurance holders based on free shares,
 *         with incentives scaled by an optimal supply threshold.
 */
contract RewardDistributor is Ownable, IRewardDistributor {
    using SafeERC20 for IERC20;

    /// @notice CommunityInsurance vault with free-balance interface
    ICommunityInsurance public communityInsurance;
    /// @notice Token distributed as reward
    IERC20 public immutable rewardToken;

    /// @notice Emission rate, in reward tokens per second
    uint256 public rewardRate;
    /// @notice Supply level at which per-share incentive switches behavior
    uint256 public optimalSupply;
    /// @notice Last timestamp the index was updated
    uint256 public lastUpdateTime;
    /// @notice Cumulative reward per free share, scaled by 1e18
    uint256 public rewardPerTokenStored;

    /// @notice Per-user snapshot of `rewardPerTokenStored` to calculate deltas
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @notice Accrued but unclaimed rewards per user
    mapping(address => uint256) public rewards;

    /**
     * @param owner_ Owner of the contract
     * @param rewardToken_ The ERC20 token used for rewards
     * @param rewardRate_ Emission rate in reward tokens per second
     * @param optimalSupply_ Supply threshold for full reward-per-token scaling
     */
    constructor(
        address owner_,
        address rewardToken_,
        uint256 rewardRate_,
        uint256 optimalSupply_
    ) Ownable(owner_) {
        rewardToken = IERC20(rewardToken_);
        rewardRate = rewardRate_;
        optimalSupply = optimalSupply_;
    }

    /**
     * @notice Owner can set the CommunityInsurance contract address
     * @param communityInsurance_ Address of the CommunityInsurance contract
     */
    function setCommunityInsurance(address communityInsurance_) external onlyOwner {
        require(communityInsurance_ != address(0), "Invalid address");
        require(address(communityInsurance) == address(0), "Already set");
        communityInsurance = ICommunityInsurance(communityInsurance_);
        emit CommunityInsuranceSet(communityInsurance_);
    }

    /**
     * @notice Update global and (optionally) a user's reward state.
     * @dev Only callable by the CommunityInsurance vault.
     * @param account   User address to sync (or zero address to skip user update)
     * @param userFree  Free (unlocked) shares of `account` before update
     * @param totalFree Total free shares across all users before update
     */
    function updateReward(
        address account,
        uint256 userFree,
        uint256 totalFree
    ) external {
        require(msg.sender == address(communityInsurance), "Only vault can update");
        _updateReward(account, userFree, totalFree);
    }

    /**
     * @dev Internal logic to update reward index and optionally a user's accrual.
     */
    function _updateReward(
        address account,
        uint256 userFree,
        uint256 totalFree
    ) internal {
        uint256 denom = totalFree < optimalSupply ? optimalSupply : totalFree;
        if (block.timestamp > lastUpdateTime && denom > 0) {
            uint256 delta = block.timestamp - lastUpdateTime;
            rewardPerTokenStored += (delta * rewardRate * 1e18) / denom;
        }
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            uint256 earned = (userFree * (rewardPerTokenStored - userRewardPerTokenPaid[account])) / 1e18;
            rewards[account] += earned;
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        
    }
    
    /**
     * @notice Owner can adjust the emission rate.
     * @param rate New tokens per second
     */
    function setRewardRate(uint256 rate) external onlyOwner {
        _updateReward(address(0), 0, communityInsurance.freeSupply());
        rewardRate = rate;
        emit RewardRateUpdated(rate);
    }

    /**
     * @notice Owner may adjust the optimal supply threshold.
     * @param _optimalSupply New target supply level
     */
    function setOptimalSupply(uint256 _optimalSupply) external onlyOwner {
        _updateReward(address(0), 0, communityInsurance.freeSupply());
        optimalSupply = _optimalSupply;
        emit OptimalSupplyUpdated(_optimalSupply);
    }

    /**
     * @notice Claim all pending rewards for caller, up to available balance.
     */
    function claimReward() external {
        _updateReward(
            msg.sender,
            communityInsurance.freeBalanceOf(msg.sender),
            communityInsurance.freeSupply()
        );
        uint256 totalOwed = rewards[msg.sender];
        if (totalOwed > 0) {
            uint256 available = rewardToken.balanceOf(address(this));
            uint256 payout = totalOwed <= available ? totalOwed : available;
            rewards[msg.sender] = totalOwed - payout;
            rewardToken.safeTransfer(msg.sender, payout);
            emit RewardPaid(msg.sender, payout);
        }
    }

    /**
     * @notice Anyone can deposit reward tokens to fund the contract.
     * @param amount Amount to deposit
     */
    function fund(uint256 amount) external {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}
