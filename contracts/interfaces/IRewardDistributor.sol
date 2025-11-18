// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICommunityInsurance.sol";

interface IRewardDistributor {
    // Views
    function communityInsurance() external view returns (ICommunityInsurance);
    function rewardToken() external view returns (IERC20);
    function rewardRate() external view returns (uint256);
    function optimalSupply() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function rewardPerTokenStored() external view returns (uint256);
    function userRewardPerTokenPaid(address user) external view returns (uint256);
    function rewards(address user) external view returns (uint256);

    // Mutative functions
    function updateReward(address account, uint256 userFree, uint256 totalFree) external;
    function setRewardRate(uint256 rate) external;
    function setOptimalSupply(uint256 _optimalSupply) external;
    function claimReward() external;
    function fund(uint256 amount) external;
    
    // Events
    event RewardRateUpdated(uint256 newRate);
    event OptimalSupplyUpdated(uint256 newOptimalSupply);
    event RewardPaid(address indexed user, uint256 reward);
    event CommunityInsuranceSet(address indexed newCommunityInsurance);
    event logUint(string who, uint256 value);
}
