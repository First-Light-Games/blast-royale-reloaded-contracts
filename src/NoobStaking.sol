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
        uint256 apr;
        uint256 chance; // chance in basis points (e.g., 6499 for 64.99%)
    }

    mapping(uint256 => AprRange[]) public aprRanges;

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

        // Initialize APR ranges and probabilities
        aprRanges[0].push(AprRange(200_000, 6499)); // 64.99%
        aprRanges[0].push(AprRange(300_000, 3400)); // 34%
        aprRanges[0].push(AprRange(400_000, 90));    // 0.9%
        aprRanges[0].push(AprRange(600_000, 10));    // 0.1%
        aprRanges[0].push(AprRange(1000_000, 1));   // 0.01%

        aprRanges[1].push(AprRange(150_000, 6499)); // 64.99%
        aprRanges[1].push(AprRange(225_000, 3400)); // 34%
        aprRanges[1].push(AprRange(300_000, 90));    // 0.9%
        aprRanges[1].push(AprRange(450_000, 10));    // 0.1%
        aprRanges[1].push(AprRange(750_000, 1));    // 0.01%

        aprRanges[2].push(AprRange(100_000, 6499)); // 64.99%
        aprRanges[2].push(AprRange(150_000, 3400)); // 34%
        aprRanges[2].push(AprRange(200_000, 90));    // 0.9%
        aprRanges[2].push(AprRange(300_000, 10));    // 0.1%
        aprRanges[2].push(AprRange(500_000, 1));    // 0.01%
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
        require(block.timestamp >= stakingEndTime, "Lucky staking not over");

        uint256 rewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, lockPeriod);
        noobToken.safeTransfer(msg.sender, stakingInfo.amount + rewards);

        _removeStake(msg.sender, StakeType.Lucky, positionId); // Remove the stake
        emit Unstaked(msg.sender, stakingInfo.amount, StakeType.Lucky, positionId);
    }

    /// <=============== View Functions ===============>

    /// @notice Function to get current claimable Rewards
    function getClaimableRewards(address _user, StakeType _type, uint256 positionId) public view returns (uint256) {
        uint256 rewards = 0;
        StakingInfo memory stakingInfo = userStakingInfo[_user][_type][positionId];
        if (stakingInfo.amount > 0) {
            uint256 _duration = stakingInfo.stakingTime + lockPeriod > block.timestamp ? block.timestamp - stakingInfo.stakingTime : lockPeriod;
            rewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, _duration);
        }
        return rewards;
    }

    /// @notice Function to get total claimable Rewards
    function getTotalClaimableRewards(address _user, StakeType _type) public view returns (uint256) {
        uint256 rewards = 0;
        for (uint256 i = 0; i < userStakingInfo[_user][_type].length; i++) {
            rewards += getClaimableRewards(_user, _type, i);
        }
        return rewards;
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
        return (_amount * _apr * _duration) / 365 days / 1_000 / 100;
    }

    // Get a random APR based on the stage after TGE
    function getRandomAPR() internal view returns (uint256) {
        uint256 timeSinceTGE = block.timestamp - tgeStart;
        uint256 apr;

        if (timeSinceTGE < 48 hours) {
            apr = getAPRWithChance(0);
        } else if (timeSinceTGE < 216 hours) { // Next week after 48 hours
            apr = getAPRWithChance(1);
        } else if (timeSinceTGE < 720 hours) { // Next 3 weeks
            apr = getAPRWithChance(2);
        } else {
            apr = 0; // Lucky staking closed
        }

        return apr;
    }

    // Helper function to get APR based on chance distribution
    function getAPRWithChance(uint256 rangeIndex) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 randomValue = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, price))
        ) % 10000;

        uint256 cumulativeChance = 0;
        AprRange[] memory ranges = aprRanges[rangeIndex];

        for (uint256 i = 0; i < ranges.length; i++) {
            cumulativeChance += ranges[i].chance;
            if (randomValue < cumulativeChance) {
                return ranges[i].apr;
            }
        }
        return ranges[0].apr;
    }

    // Helper function to get a random number in range
    function randomInRange(uint256 _min, uint256 _max) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) % (_max - _min + 1) + _min;
    }

    /// <=============== Admin Functions ===============>
    /// @notice Set APR for fixed staking
    function setFixedAPR(uint256 _apr) external onlyOwner {
        fixedAPR = _apr;
    }

    /// @notice Set tgeStart time
    function setTgeStart(uint256 _tgeStart) external onlyOwner {
        require(tgeStart <= block.timestamp, "TGE already started");
        require(_tgeStart >= block.timestamp, "New TGE must be in the future");
        tgeStart = _tgeStart;
    }

    /// @notice Set fixedStakingDuration
    function setFixedStakingDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0, "Duration must be greater than 0");
        fixedStakingDuration = _duration;
    }

    /// @notice Set luckyStakingDuration
    function setLuckyStakingDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0, "Duration must be greater than 0");
        luckyStakingDuration = _duration;
    }

    /// @notice Set luckyMaxStake
    function setLuckyMaxStake(uint256 _maxStake) external onlyOwner {
        require(_maxStake > 0, "Max stake must be greater than 0");
        luckyMaxStake = _maxStake;
    }

    /// @notice Enable/Disable lucky staking
    function toggleLuckyStaking(bool _enabled) external onlyOwner {
        luckyEnabled = _enabled;
    }

    /// @notice Enable/Disable fixed staking
    function toggleFixedStaking(bool _enabled) external onlyOwner {
        fixedEnabled = _enabled;
    }

    /// @notice Function to withdraw tokens
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(
            noobToken.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        noobToken.safeTransfer(owner(), amount);
    }

    /// @notice Function to pause the contract (for emergency)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Function to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
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
        StakingInfo memory stakingInfo = userStakingInfo[_staker][_stakeType][_index];

        uint256 rewards = calculateRewards(stakingInfo.amount, stakingInfo.apr, lockPeriod);

        totalRewards += rewards;

        require(totalRewards <= totalRewardsLimit, "Staking rewards limit reached");
    }
}