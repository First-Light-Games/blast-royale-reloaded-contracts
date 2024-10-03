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
    event Staked(address indexed staker, uint256 amount, StakeType stakeType);
    event Claimed(address indexed staker, uint256 rewards, StakeType stakeType);
    event Unstaked(address indexed staker, uint256 amount, StakeType stakeType);

    /// <=============== STATE VARIABLES ===============>
    uint256 public tgeStart;
    uint256 public fixedStakingDuration = 90 days;
    uint256 public fixedLockPeriod = 180 days;
    uint256 public gamblingStakingDuration = 30 days;
    uint256 public fixedAPR = 80_000;
    uint256 private safetyNet = 50_000_000 * 1e18; // Hidden value for potential rewards limit

    AggregatorV3Interface internal priceFeed;
    IERC20 public noobToken;

    // Enum for stake types
    enum StakeType { Fixed, Gambling }

    struct StakingInfo {
        uint256 amount;
        uint256 stakingTime;
        uint256 apr;
        bool isGambling;
    }

    mapping(address => mapping(StakeType => StakingInfo)) public userStakingInfo;

    constructor(address _tokenAddress, address _owner, uint256 _tgeStart, address _priceFeed) Ownable(_owner) {
        require(_tokenAddress != address(0), "NoobToken address cannot be 0");
        require(_owner != address(0), "Invalid owner address");
        require(_priceFeed != address(0), "Invalid price feed address");
        require(_tgeStart > block.timestamp, "TGE start time cannot be in the past");

        priceFeed = AggregatorV3Interface(_priceFeed);
        noobToken = IERC20(_tokenAddress);
        tgeStart = _tgeStart;
    }

    modifier checkSafetyNet(uint256 _amount, uint256 _potentialRewards) {
        require(getPotentialRewardPool() + _potentialRewards <= safetyNet, "Safety net exceeded");
        _;
    }

    // Fixed staking logic
    function stakeFixed(uint256 _amount) external checkSafetyNet(_amount, calculateFixedRewards(_amount)) {
        require(block.timestamp >= tgeStart, "Staking not started");
        require(block.timestamp <= tgeStart + fixedStakingDuration, "Fixed staking closed");

        noobToken.safeTransferFrom(msg.sender, address(this), _amount);

        userStakingInfo[msg.sender][StakeType.Fixed] = StakingInfo({
            amount: _amount,
            stakingTime: block.timestamp,
            apr: fixedAPR,
            isGambling: false
        });
    }

    // Early withdraw with reward forfeiture
    function withdrawFixed() external {
        StakingInfo memory staker = userStakingInfo[msg.sender][StakeType.Fixed];
        require(staker.amount > 0, "No stake");
        require(!staker.isGambling, "Invalid staking type");

        uint256 stakingEndTime = staker.stakingTime + fixedLockPeriod;
        if (block.timestamp < stakingEndTime) {
            // Early withdraw
            noobToken.safeTransfer(msg.sender, staker.amount); // No rewards
        } else {
            // Full withdraw with rewards
            uint256 rewards = calculateFixedRewards(staker.amount);
            noobToken.safeTransfer(msg.sender, staker.amount + rewards);
        }

        delete userStakingInfo[msg.sender][StakeType.Fixed]; // Reset staker
    }

    // Gambling staking logic with random APR based on time
    function stakeGambling(uint256 _amount) external checkSafetyNet(_amount, calculateGamblingRewards(_amount)) {
        require(block.timestamp >= tgeStart, "Staking not started");
        require(block.timestamp <= tgeStart + gamblingStakingDuration, "Gambling staking closed");
        require(_amount <= 1_000_000 * 1e18, "Stake exceeds limit");

        uint256 apr = getRandomAPR();
        require(apr > 0, "Gambling stake is unavailable");
        noobToken.safeTransferFrom(msg.sender, address(this), _amount);

        userStakingInfo[msg.sender][StakeType.Gambling] = StakingInfo({
            amount: _amount,
            stakingTime: block.timestamp,
            apr: apr,
            isGambling: true
        });
    }

    /// <=============== View Functions ===============>
    // Calculate rewards for fixed staking
    function calculateFixedRewards(uint256 _amount) internal view returns (uint256) {
        return (_amount * fixedAPR * fixedLockPeriod) / (100 * 365 days) / 1_000; // Simplified calculation
    }

    // Calculate rewards for gambling staking
    function calculateGamblingRewards(uint256 _amount) internal view returns (uint256) {
        StakingInfo memory staker = userStakingInfo[msg.sender][StakeType.Gambling];
        return (_amount * staker.apr * fixedLockPeriod) / (100 * 365 days);
    }

    // Get a random APR based on current time since TGE
    function getRandomAPR() internal view returns (uint256) {
        uint256 timeSinceTGE = block.timestamp - tgeStart;
        if (timeSinceTGE < 6 hours) {
            return randomInRange(200, 1000);
        } else if (timeSinceTGE < 7 days) {
            return randomInRange(150, 750);
        } else if (timeSinceTGE < 30 days) {
            return randomInRange(100, 500);
        }
        return 0; // Gambling staking is closed after 1 month
    }

    // Helper function to get a random number in range (simplified for demonstration)
    function randomInRange(uint256 _min, uint256 _max) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) % (_max - _min + 1) + _min;
    }

    // Get the total potential reward pool
    function getPotentialRewardPool() public view returns (uint256) {
        uint256 totalPotentialRewards = 0;
        // Logic to sum up potential rewards of all userStakingInfo
        return totalPotentialRewards;
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
}
