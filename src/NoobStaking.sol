// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; // Oracle interface
import "@openzeppelin/contracts/access/Ownable.sol"; // Access control

contract StakingContract is ReentrancyGuard, Ownable {
    IERC20 public stakingToken;
    AggregatorV3Interface public priceOracle; // Oracle for randomness

    struct Staker {
        uint256 stakedAmount;
        uint256 rewards;
        uint256 APR;
        uint256 lockEndTime;
        uint256 lastClaimTime;
        StakingType stakingType;
    }

    enum StakingType {
        Flexible,
        Fixed,
        Gambling
    }

    mapping(address => Staker) public stakers;
    uint256 public flexibleAPR = 15; // Default flexible APR 15%
    uint256 public fixedAPR = 80; // Default fixed APR 80%
    uint256 public gamblingMaxAPR = 1000; // Gambling APR starts at max 1000%
    uint256 public safetyNetLimit = 50e6 * (10 ** 18); // Safety net for Fixed + Gambling staking in tokens

    uint256 public totalStakedInFixedAndGambling;

    event Staked(address indexed user, uint256 amount, StakingType stakingType);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 rewards);
    event ClaimAndStaked(address indexed user, uint256 amount);

    modifier validateStakeAmount(uint256 amount, StakingType stakingType) {
        require(amount > 0, "Amount must be greater than 0");
        if (stakingType == StakingType.Gambling) {
            require(amount <= 1e6 * (10 ** 18), "Max 1m tokens in Gambling"); // Adjusted for wei
        }
        _;
    }

    constructor(address _stakingToken, address _oracle) {
        stakingToken = IERC20(_stakingToken);
        priceOracle = AggregatorV3Interface(_oracle);
    }

    // Main staking function with logic for all staking types
    function stake(
        uint256 amount,
        StakingType stakingType
    ) external nonReentrant validateStakeAmount(amount, stakingType) {
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Stake failed"
        );

        uint256 APR = determineAPR(stakingType);
        uint256 lockPeriod = stakingType == StakingType.Flexible
            ? 0
            : block.timestamp + 180 days; // 6 months lock period

        // Update staker's details
        Staker storage staker = stakers[msg.sender];
        staker.stakedAmount += amount;
        staker.APR = APR;
        staker.lockEndTime = lockPeriod;
        staker.lastClaimTime = block.timestamp;
        staker.stakingType = stakingType;

        // Update total staked for Fixed and Gambling, ensure safety net
        if (
            stakingType == StakingType.Fixed ||
            stakingType == StakingType.Gambling
        ) {
            require(
                totalStakedInFixedAndGambling +
                    amount +
                    calculatePotentialReward(amount, APR, lockPeriod) <=
                    safetyNetLimit,
                "Exceeds safety net"
            );
            totalStakedInFixedAndGambling += amount;
        }

        emit Staked(msg.sender, amount, stakingType);
    }

    // Claim rewards
    function claim() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount > 0, "No staked tokens");

        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards");

        staker.rewards = 0;
        staker.lastClaimTime = block.timestamp;

        require(stakingToken.transfer(msg.sender, rewards), "Claim failed");

        emit Claimed(msg.sender, rewards);
    }

    // Claim and immediately stake the rewards
    function claimAndStake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount > 0, "No staked tokens");

        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards");

        staker.rewards = 0;
        staker.lastClaimTime = block.timestamp;

        // Compound rewards into Flexible staking
        stake(rewards, StakingType.Flexible);

        emit ClaimAndStaked(msg.sender, rewards);
    }

    // Unstake tokens
    function unstake(uint256 amount) external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount >= amount, "Not enough staked");

        if (staker.stakingType == StakingType.Fixed) {
            if (block.timestamp < staker.lockEndTime) {
                // Reset rewards if unstaking early
                staker.rewards = 0; // User loses rewards
            } else {
                require(
                    block.timestamp >= staker.lockEndTime,
                    "Lock period not over"
                );
            }
        } else if (staker.stakingType == StakingType.Gambling) {
            require(
                block.timestamp >= staker.lockEndTime,
                "Lock period not over"
            );
        }

        staker.stakedAmount -= amount;
        require(stakingToken.transfer(msg.sender, amount), "Unstake failed");

        emit Unstaked(msg.sender, amount);
    }

    // Determine APR based on staking type
    function determineAPR(
        StakingType stakingType
    ) internal view returns (uint256) {
        if (stakingType == StakingType.Gambling) {
            return getRandomAPR();
        } else if (stakingType == StakingType.Fixed) {
            return fixedAPR;
        }
        return flexibleAPR;
    }

    // Use the oracle to determine random APR for gambling staking
    function getRandomAPR() internal view returns (uint256) {
        (, int256 randomValue, , , ) = priceOracle.latestRoundData(); // Simulate randomness using Chainlink oracle

        uint256 chance = uint256(randomValue % 100); // Random chance calculation
        if (chance >= 99) {
            return 500;
        } else if (chance >= 90) {
            return 300;
        } else if (chance >= 60) {
            return 200;
        } else if (chance >= 35) {
            return 150;
        } else {
            return 100;
        }
    }

    // Calculate rewards based on the staking amount, APR, and time staked
    function calculateRewards(address user) public view returns (uint256) {
        Staker storage staker = stakers[user];
        uint256 timeStaked = block.timestamp - staker.lastClaimTime;
        return
            calculatePotentialReward(
                staker.stakedAmount,
                staker.APR,
                timeStaked
            );
    }

    // Calculate potential reward for a given amount, APR, and time
    function calculatePotentialReward(
        uint256 amount,
        uint256 APR,
        uint256 timeStaked
    ) internal pure returns (uint256) {
        return (amount * APR * timeStaked) / (365 days * 100);
    }

    // Admin function to set flexible APR
    function setFlexibleAPR(uint256 newAPR) external onlyOwner {
        flexibleAPR = newAPR;
    }

    // Admin function to set fixed APR
    function setFixedAPR(uint256 newAPR) external onlyOwner {
        fixedAPR = newAPR;
    }

    // Admin function to set gambling APR range
    function setGamblingMaxAPR(uint256 newMaxAPR) external onlyOwner {
        gamblingMaxAPR = newMaxAPR;
    }

    // Admin function to adjust safety net limit
    function setSafetyNetLimit(uint256 newLimit) external onlyOwner {
        safetyNetLimit = newLimit;
    }

    // Admin function to adjust oracle
    function setOracle(address newOracle) external onlyOwner {
        priceOracle = AggregatorV3Interface(newOracle);
    }
}
