// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract NoobFlexibleStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// <=============== Events ===============>
    event Staked(address indexed user, uint256 positionId, uint256 amount);
    event Claimed(address indexed user, uint256 positionId, uint256 rewards);
    event Unstaked(address indexed user, uint256 positionId, uint256 amount);
    event AprUpdated(uint256 newApr, uint256 timestamp);

    /// <=============== STATE VARIABLES ===============>
    IERC20 public noobToken;

    // Struct to hold user's stake details
    struct Stake {
        uint256 amount; // Total staked amount
        uint256 lastUpdatedAt; // Last time rewards were claimed or updated
        uint256 rewards; // Accumulated rewards
        uint256 lastApr; // Last APR used for reward calculation
    }

    // Mapping to keep track of user's multiple staking positions
    mapping(address => Stake[]) public userStakes;

    // Historical APR changes
    struct AprChange {
        uint256 apr; // APR value
        uint256 timestamp; // Time when this APR was set
    }

    // Array to store the APR changes
    AprChange[] public aprHistory;

    // Minimum cooldown period for Claim & Stake (in seconds)
    uint256 public constant COOLDOWN_PERIOD = 24 hours;
    uint256 public tgeStart;

    constructor(address _noobToken, uint256 initialApr, address _owner, uint256 _tgeStart) Ownable(_owner) {
        require(_noobToken != address(0), "NoobToken address cannot be 0");
        require(initialApr > 0, "Initial APR must be greater than 0");
        require(_tgeStart >= block.timestamp, "TGE must be in the future");

        noobToken = IERC20(_noobToken);
        aprHistory.push(AprChange({apr: initialApr, timestamp: block.timestamp}));
        tgeStart = _tgeStart;
    }

    /// @notice Function to create or add to a flexible stake
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(block.timestamp >= tgeStart, "Staking not started");

        // Transfer tokens to the contract
        noobToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Add a new stake for the user
        Stake memory newStake = Stake({
            amount: _amount,
            lastUpdatedAt: block.timestamp,
            rewards: 0,
            lastApr: aprHistory[aprHistory.length - 1].apr
        });
        userStakes[msg.sender].push(newStake);

        uint256 positionId = userStakes[msg.sender].length - 1;
        emit Staked(msg.sender, positionId, _amount);
    }

    /// @notice Function to claim staking rewards
    function claimStakeRewards(uint256 positionId) external whenNotPaused nonReentrant {
        require(positionId < userStakes[msg.sender].length, "Invalid position ID");

        _updateRewards(msg.sender, positionId);

        Stake storage userStake = userStakes[msg.sender][positionId];
        uint256 rewards = userStake.rewards;
        require(rewards > 0, "No rewards available");

        // Reset rewards
        userStake.rewards = 0;
        userStake.lastUpdatedAt = block.timestamp;

        // Transfer rewards to user
        noobToken.safeTransfer(msg.sender, rewards);

        // Emit event
        emit Claimed(msg.sender, positionId, rewards);
    }

    /// @notice Function to claim and stake rewards (compound)
    function claimAndStake(uint256 positionId) external whenNotPaused nonReentrant {
        require(positionId < userStakes[msg.sender].length, "Invalid position ID");
        Stake storage userStake = userStakes[msg.sender][positionId];

        require(
            block.timestamp >= userStake.lastUpdatedAt + COOLDOWN_PERIOD,
            "Claim & Stake can only be done once in 24 hours"
        );

        _updateRewards(msg.sender, positionId);

        uint256 rewards = userStake.rewards;
        require(rewards > 0, "No rewards available");

        // Reset rewards and update last updated time
        userStake.rewards = 0;
        userStake.lastUpdatedAt = block.timestamp;

        // Add rewards to stake
        userStake.amount += rewards;

        // Emit event
        emit Staked(msg.sender, positionId,rewards);
    }

    /// @notice Function to unstake all staked tokens and claim rewards
    function unstake(uint256 positionId) external whenNotPaused nonReentrant {
        require(positionId < userStakes[msg.sender].length, "Invalid position ID");

        _updateRewards(msg.sender, positionId);

        Stake storage userStake = userStakes[msg.sender][positionId];
        uint256 totalAmount = userStake.amount + userStake.rewards;

        require(totalAmount > 0, "Nothing to unstake");

        // Reset user's stake
        delete userStakes[msg.sender][positionId];

        // Transfer total amount back to user
        noobToken.safeTransfer(msg.sender, totalAmount);

        // Emit event
        emit Unstaked(msg.sender, positionId, totalAmount);
    }

    /// @notice Function to get current claimable Rewards
    function getClaimableRewards(address _user, uint256 _positionId) public view returns (uint256) {
        uint256 totalRewards = 0;
        Stake memory _stake = userStakes[_user][_positionId];
        if (_stake.amount > 0) {
            uint256 lastAprTimestamp = _stake.lastUpdatedAt;

            if (lastAprTimestamp >= aprHistory[aprHistory.length - 1].timestamp) {
                totalRewards += _calculateRewards(_stake.amount, aprHistory[aprHistory.length - 1].apr, lastAprTimestamp, block.timestamp);
            } else {
                for (uint256 i = 0; i < aprHistory.length; i++) {
                    uint256 nextTimestamp = (i < aprHistory.length - 1) ? aprHistory[i + 1].timestamp : block.timestamp;
                    totalRewards += _calculateRewards(_stake.amount, aprHistory[i].apr, lastAprTimestamp, nextTimestamp);
                    lastAprTimestamp = nextTimestamp;
                }
            }
        }
        return totalRewards;
    }

    /// @notice Function to get total claimable Rewards
    function getTotalClaimableRewards(address _user) public view returns (uint256) {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < userStakes[_user].length; i++) {
            totalRewards += getClaimableRewards(_user, i);
        }
        return totalRewards;
    }

    /// @notice Function to get total stakedAmount
    function getTotalStakedAmount(address _user) public view returns (uint256) {
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < userStakes[_user].length; i++) {
            totalStakedAmount += userStakes[_user][i].amount;
        }
        return totalStakedAmount;
    }

    /// @notice Function to get total staked count
    function getStakedCount(address _user) public view returns (uint256) {
        return userStakes[_user].length;
    }

    /// @notice Function to calculate and update rewards for a user
    function _updateRewards(address _user, uint256 _positionId) internal {
        Stake storage _stake = userStakes[_user][_positionId];
        uint256 amount = _stake.amount;

        if (amount > 0) {
            uint256 accumulatedRewards = 0;
            uint256 lastAprTimestamp = _stake.lastUpdatedAt;

            if (lastAprTimestamp >= aprHistory[aprHistory.length - 1].timestamp) {
                accumulatedRewards += _calculateRewards(_stake.amount, aprHistory[aprHistory.length - 1].apr, lastAprTimestamp, block.timestamp);
            } else {
                for (uint256 i = 0; i < aprHistory.length; i++) {
                    uint256 nextTimestamp = (i < aprHistory.length - 1) ? aprHistory[i + 1].timestamp : block.timestamp;
                    accumulatedRewards += _calculateRewards(amount, aprHistory[i].apr, lastAprTimestamp, nextTimestamp);
                    lastAprTimestamp = nextTimestamp;
                }
            }

            _stake.rewards += accumulatedRewards;
        }
    }

    /// @notice Function to calculate rewards for a given period
    function _calculateRewards(
        uint256 _amount,
        uint256 _apr,
        uint256 _from,
        uint256 _to
    ) internal view returns (uint256) {
        if (_from >= _to) return 0;
        uint256 duration = _to - _from;
        return (_amount * _apr * duration) / (365 days * 1000) / 100;
    }

    /// @notice Function to get the current APR
    function getCurrentApr() public view returns (uint256) {
        return aprHistory[aprHistory.length - 1].apr;
    }

    /// <=============== Admin Functions ===============>
    /// @notice Function to update the global APR
    function updateApr(uint256 _newApr) external onlyOwner {
        require(_newApr > 0, "APR must be greater than 0");
        aprHistory.push(AprChange({apr: _newApr, timestamp: block.timestamp}));

        // Emit event
        emit AprUpdated(_newApr, block.timestamp);
    }

    /// @notice Function to pause the contract (for emergency)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Function to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Function to withdraw tokens
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(
            noobToken.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        noobToken.safeTransfer(owner(), amount);
    }
}
