// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@chainlink/interfaces/AggregatorV3Interface.sol";

contract NoobStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// <=============== Events ===============>
    event Staked(address indexed staker, uint256 amount, StakeType stakeType, uint256 positionId);
    event Claimed(address indexed staker, uint256 rewards, StakeType stakeType, uint256 positionId);
    event Unstaked(address indexed staker, uint256 amount, StakeType stakeType, uint256 positionId);

    /// <=============== STATE VARIABLES ===============>
    struct AprRange {
        uint256 min;
        uint256 max;
    }

    AprRange[] public aprRanges;

    uint256 private totalRewardsLimit;
    uint256 public totalRewards;
    uint256 public luckyMaxStake = 1_000_000 * 1e18;
    uint256 public tgeStart;
    uint256 public fixedStakingDuration = 90 days;
    uint256 public lockPeriod = 180 days;
    uint256 public luckyStakingDuration = 30 days;
    uint256 public fixedAPR = 80_000;

    bool public luckyEnabled;
    bool public fixedEnabled;

    AggregatorV3Interface internal priceFeed;
    IERC20 public noobToken;

    // Enum for stake types
    enum StakeType { Fixed, Lucky }

    struct StakingInfo {
        uint256 amount;
        uint256 stakingTime;
        uint256 apr;
    }

    mapping(address => mapping(StakeType => StakingInfo[])) public userStakingInfo;

    constructor(address _tokenAddress, address _owner, uint256 _tgeStart, uint256 _totalRewardsLimit, address _priceFeed) Ownable(_owner) {
        require(_tokenAddress != address(0), "NoobToken address cannot be 0");
        require(_owner != address(0), "Invalid owner address");
        require(_priceFeed != address(0), "Invalid price feed address");
        require(_tgeStart >= block.timestamp, "TGE must be in the future");

        priceFeed = AggregatorV3Interface(_priceFeed);
        noobToken = IERC20(_tokenAddress);
        tgeStart = _tgeStart;
        totalRewardsLimit = _totalRewardsLimit;

        luckyEnabled = true;
        fixedEnabled = true;

        // Initialize default APR ranges
        aprRanges.push(AprRange(200_000, 1_000_000));  // First 6 hours
        aprRanges.push(AprRange(150_000, 750_000));   // Next 7 days
        aprRanges.push(AprRange(100_000, 500_000));   // Next 3 weeks
    }

    modifier whenLuckyModeEnabled() {
        require(luckyEnabled, "Lucky staking is disabled");
        _;
    }

    modifier whenFixedModeEnabled() {
        require(fixedEnabled, "Fixed staking is disabled");
        _;
    }

    // Fixed staking logic
    function stakeFixed(uint256 _amount) external whenNotPaused nonReentrant whenFixedModeEnabled {
        require(block.timestamp >= tgeStart, "Staking not started");
        require(block.timestamp <= tgeStart + fixedStakingDuration, "Fixed staking closed");

        noobToken.safeTransferFrom(msg.sender, address(this), _amount);

        userStakingInfo[msg.sender][StakeType.Fixed].push(StakingInfo({
            amount: _amount,
            stakingTime: block.timestamp,
            apr: fixedAPR
        }));

        uint256 positionId = userStakingInfo[msg.sender][StakeType.Fixed].length - 1;

        _checkSafetyNet(msg.sender, StakeType.Fixed, positionId);

        emit Staked(msg.sender, _amount, StakeType.Fixed, positionId);
    }

    // Early withdraw with reward forfeiture
    function withdrawFixed(uint256 positionId) external whenNotPaused nonReentrant {
        StakingInfo memory stakingInfo = userStakingInfo[msg.sender][StakeType.Fixed][positionId];
        require(stakingInfo.amount > 0, "No stake");

        uint256 stakingEndTime = stakingInfo.stakingTime + lockPeriod;
        uint256 rewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, lockPeriod);
        if (block.timestamp < stakingEndTime) {
            // Early withdraw
            noobToken.safeTransfer(msg.sender, stakingInfo.amount); // No rewards
            totalRewards -= rewards; // free up rewards that actually didn't get claimed
        } else {
            // Full withdraw with rewards
            noobToken.safeTransfer(msg.sender, stakingInfo.amount + rewards);
        }

        _removeStake(msg.sender, StakeType.Fixed, positionId); // Remove the stake
        emit Unstaked(msg.sender, stakingInfo.amount, StakeType.Fixed, positionId);
    }

    // Lucky staking logic with dynamic APR ranges and time pressure
    function stakeLucky(uint256 _amount) external whenNotPaused nonReentrant whenLuckyModeEnabled {
        require(block.timestamp >= tgeStart, "Staking not started");
        require(block.timestamp <= tgeStart + luckyStakingDuration, "Lucky staking closed");
        require(_amount > 0, "Stake amount must be greater than 0");
        require(_amount <= luckyMaxStake, "Stake exceeds limit");

        uint256 apr = getRandomAPR();
        require(apr > 0, "Lucky stake is unavailable");
        noobToken.safeTransferFrom(msg.sender, address(this), _amount);

        userStakingInfo[msg.sender][StakeType.Lucky].push(StakingInfo({
            amount: _amount,
            stakingTime: block.timestamp,
            apr: apr
        }));

        uint256 positionId = userStakingInfo[msg.sender][StakeType.Lucky].length - 1;

        _checkSafetyNet(msg.sender, StakeType.Lucky, positionId);

        emit Staked(msg.sender, _amount, StakeType.Lucky, positionId);
    }

    // Withdraw from lucky staking
    function withdrawLucky(uint256 positionId) external whenNotPaused nonReentrant {
        StakingInfo memory stakingInfo = userStakingInfo[msg.sender][StakeType.Lucky][positionId];
        require(stakingInfo.amount > 0, "No stake");

        uint256 stakingEndTime = stakingInfo.stakingTime + lockPeriod;
        uint256 rewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, lockPeriod);

        if (block.timestamp < stakingEndTime) {
            // Early withdraw
            noobToken.safeTransfer(msg.sender, stakingInfo.amount); // No rewards
            totalRewards -= rewards; // free up rewards that actually didn't get claimed
        } else {
            // Full withdraw with rewards
            noobToken.safeTransfer(msg.sender, stakingInfo.amount + rewards);
        }

        _removeStake(msg.sender, StakeType.Lucky, positionId); // Remove the stake
        emit Unstaked(msg.sender, stakingInfo.amount, StakeType.Lucky, positionId);
    }

    /// <=============== View Functions ===============>

    /// @notice Function to get current claimable Rewards
    function getClaimableRewards(address _user, StakeType _type, uint256 positionId) public view returns (uint256) {
        uint256 totalRewards = 0;
        StakingInfo memory stakingInfo = userStakingInfo[_user][_type][positionId];
        if (stakingInfo.amount > 0) {
            uint256 _duration = stakingInfo.stakingTime + lockPeriod - block.timestamp > 0 ? block.timestamp - stakingInfo.stakingTime : lockPeriod;
            totalRewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, _duration);
        }
        return totalRewards;
    }

    /// @notice Function to get total claimable Rewards
    function getTotalClaimableRewards(address _user, StakeType _type) public view returns (uint256) {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < userStakingInfo[_user][_type].length; i++) {
            totalRewards += getClaimableRewards(_user, _type, i);
        }
        return totalRewards;
    }

    /// @notice Function to get total stakedAmount
    function getTotalStakedAmount(address _user, StakeType _type) public view returns (uint256) {
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < userStakingInfo[_user][_type].length; i++) {
            totalStakedAmount += userStakingInfo[_user][_type][i].amount;
        }
        return totalStakedAmount;
    }

    /// @notice Function to get total staked count
    function getStakedCount(address _user, StakeType _type) public view returns (uint256) {
        return userStakingInfo[_user][_type].length;
    }

    // Calculate rewards
    function calculateRewards(uint256 _amount, uint256 _apr, uint256 _duration) internal pure returns (uint256) {
        return (_amount * _apr * _duration) / 365 days / 1_000 / 100; // Simplified calculation
    }

    // Get a random APR based on the stage after TGE
    function getRandomAPR() internal view returns (uint256) {
        uint256 timeSinceTGE = block.timestamp - tgeStart;
        uint256 apr;

        if (timeSinceTGE < 48 hours) {
            apr = randomInRange(aprRanges[0].min, aprRanges[0].max);
        } else if (timeSinceTGE < 216 hours) { // Next week after 48 hours
            apr = randomInRange(aprRanges[1].min, aprRanges[1].max);
        } else if (timeSinceTGE < 720 hours) { // Next 3 weeks
            apr = randomInRange(aprRanges[2].min, aprRanges[2].max);
        } else {
            apr = 0; // Lucky staking closed
        }

        return apr;
    }

    // Helper function to get a random number in range (simplified for demonstration)
    function randomInRange(uint256 _min, uint256 _max) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) % (_max - _min + 1) + _min;
    }

    /// <=============== Admin Functions ===============>
    // Set APR for fixed staking
    function setFixedAPR(uint256 _apr) external onlyOwner {
        fixedAPR = _apr;
    }

    // Set fixedStakingDuration
    function setFixedStakingDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0, "Duration must be greater than 0");
        fixedStakingDuration = _duration;
    }

    // Set luckyStakingDuration
    function setLuckyStakingDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0, "Duration must be greater than 0");
        luckyStakingDuration = _duration;
    }

    // Set luckyMaxStake
    function setLuckyMaxStake(uint256 _maxStake) external onlyOwner {
        require(_maxStake > 0, "Max stake must be greater than 0");
        luckyMaxStake = _maxStake;
    }

    // Enable/Disable lucky staking
    function toggleLuckyStaking(bool _enabled) external onlyOwner {
        luckyEnabled = _enabled;
    }

    // Enable/Disable fixed staking
    function toggleFixedStaking(bool _enabled) external onlyOwner {
        fixedEnabled = _enabled;
    }

    // Set APR ranges
    function setAPRRange(uint256 _index, uint256 _min, uint256 _max) external onlyOwner {
        require(_max > _min, "Max must be greater than min");
        require(_index < aprRanges.length, "Invalid index");
        aprRanges[_index].min = _min;
        aprRanges[_index].max = _max;
    }

    /// @notice Function to withdraw tokens
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(
            noobToken.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        noobToken.safeTransfer(owner(), amount);
    }

    /// <=============== Internal Helper Functions ===============>

    // Internal function to remove a specific stake from the array
    function _removeStake(address _staker, StakeType _stakeType, uint256 _index) internal {
        require(_index < userStakingInfo[_staker][_stakeType].length, "Invalid stake index");

        // Get the staking info array for the user and stake type
        StakingInfo[] storage stakes = userStakingInfo[_staker][_stakeType];

        // Remove the specified stake by replacing it with the last element and then reducing the array size
        if (_index != stakes.length - 1) {
            stakes[_index] = stakes[stakes.length - 1]; // Replace with the last element
        }

        stakes.pop(); // Remove the last element
    }

    function _checkSafetyNet(address _staker, StakeType _stakeType, uint256 _index) internal {
        StakingInfo memory stakingInfo = userStakingInfo[msg.sender][_stakeType][_index];

        uint256 rewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, lockPeriod);

        totalRewards += rewards;

        require(totalRewards < totalRewardsLimit, "Staking rewards limit reached");
    }
}