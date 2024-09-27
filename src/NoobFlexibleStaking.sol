// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract NoobFlexibleStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// <=============== Events ===============>
    event Staked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 rewards);
    event Unstaked(address indexed user, uint256 amount);
    event AprUpdated(uint256 newApr);

    /// <=============== STATE VARIABLES ===============>
    IERC20 public noobToken;

    // Struct to hold user's stake details
    struct Stake {
        uint256 amount; // Total staked amount
        uint256 lastClaimedAt; // Last time rewards were claimed or updated
        uint256 rewards; // Accumulated rewards
        uint256 lastApr; // Last APR used for reward calculation
    }

    // Mapping to keep track of user stakes
    mapping(address => Stake) public userStakes;

    // Historical APR changes
    struct AprChange {
        uint256 apr; // APR value with two decimals, e.g., 15% = 1500
        uint256 timestamp; // Time when this APR was set
    }

    // Array to store the APR changes
    AprChange[] public aprHistory;

    // Minimum cooldown period for Claim & Stake (in seconds)
    uint256 public constant COOLDOWN_PERIOD = 24 hours;

    constructor(address _noobToken, uint256 initialApr, address _owner) Ownable(_owner) {
        require(_noobToken != address(0), "NoobToken address cannot be 0");
        require(initialApr > 0, "Initial APR must be greater than 0");

        noobToken = IERC20(_noobToken);
        aprHistory.push(AprChange({apr: initialApr, timestamp: block.timestamp}));
    }

    /// @notice Function to create or add to a flexible stake
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");

        // Transfer tokens to the contract
        noobToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Update rewards based on current APR before adding new amount
        _updateRewards(msg.sender);

        // Update user stake
        userStakes[msg.sender].amount += _amount;

        // Emit event
        emit Staked(msg.sender, _amount);
    }

    /// @notice Function to claim staking rewards
    function claimStakeRewards() external whenNotPaused nonReentrant {
        _updateRewards(msg.sender);

        uint256 rewards = userStakes[msg.sender].rewards;
        require(rewards > 0, "No rewards available");

        // Reset rewards
        userStakes[msg.sender].rewards = 0;

        // Transfer rewards to user
        noobToken.safeTransfer(msg.sender, rewards);

        // Emit event
        emit Claimed(msg.sender, rewards);
    }

    /// @notice Function to claim and stake rewards (compound)
    function claimAndStake() external whenNotPaused nonReentrant {
        require(
            block.timestamp >= userStakes[msg.sender].lastClaimedAt + COOLDOWN_PERIOD,
            "Claim & Stake can only be done once in 24 hours"
        );

        _updateRewards(msg.sender);

        uint256 rewards = userStakes[msg.sender].rewards;
        require(rewards > 0, "No rewards available");

        // Reset rewards
        userStakes[msg.sender].rewards = 0;

        // Add rewards to stake
        userStakes[msg.sender].amount += rewards;

        // Emit event
        emit Staked(msg.sender, rewards);
    }

    /// @notice Function to unstake all staked tokens and claim rewards
    function unstake() external whenNotPaused nonReentrant {
        _updateRewards(msg.sender);

        uint256 totalAmount = userStakes[msg.sender].amount + userStakes[msg.sender].rewards;

        require(totalAmount > 0, "Nothing to unstake");

        // Reset user's stake
        delete userStakes[msg.sender];

        // Transfer total amount back to user
        noobToken.safeTransfer(msg.sender, totalAmount);

        // Emit event
        emit Unstaked(msg.sender, totalAmount);
    }

    /// @notice Function to get current claimable Rewards
    function getClaimableRewards(address _user) public view returns (uint256) {
        uint256 totalRewards = 0;
        Stake storage _stake = userStakes[_user];
        if (_stake.amount > 0) {
            totalRewards += _calculateRewards(_stake.amount, _stake.lastApr, _stake.lastClaimedAt, block.timestamp);
        }
        return totalRewards;
    }

    /// @notice Function to calculate and update rewards for a user
    function _updateRewards(address _user) internal {
        Stake storage _stake = userStakes[_user];
        uint256 lastClaimedAt = _stake.lastClaimedAt;
        uint256 amount = _stake.amount;
        uint256 lastApr = _stake.lastApr;

        if (amount > 0) {
            // Calculate accumulated rewards
            if (aprHistory.length > 1) {
                for (uint256 i = 1; i < aprHistory.length; i++) {
                    uint256 accumulatedRewards = _calculateRewards(amount, aprHistory[i-1].apr, lastClaimedAt, aprHistory[i].timestamp);
                    _stake.rewards += accumulatedRewards;
                }
                uint256 accumulatedRewards = _calculateRewards(amount, aprHistory[aprHistory.length - 1].apr, lastClaimedAt, block.timestamp);
                _stake.rewards += accumulatedRewards;
            } else {
                uint256 accumulatedRewards = _calculateRewards(amount, aprHistory[0].apr, lastClaimedAt, block.timestamp);
                _stake.rewards += accumulatedRewards;
            }
        }

        // Update last claimed time and APR
        _stake.lastClaimedAt = block.timestamp;
        _stake.lastApr = getCurrentApr();
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
        return (_amount * _apr * duration) / (365 days * 1000);
    }

    /// @notice Function to get the current APR
    function getCurrentApr() public view returns (uint256) {
        return aprHistory[aprHistory.length - 1].apr;
    }

    /// @notice Function to update the global APR
    function updateApr(uint256 _newApr) external onlyOwner {
        require(_newApr > 0, "APR must be greater than 0");
        aprHistory.push(AprChange({apr: _newApr, timestamp: block.timestamp}));

        // Emit event
        emit AprUpdated(_newApr);
    }

    /// @notice Function to get the current APR
    function getCurrentApr() public view returns (uint256) {
        return aprHistory[aprHistory.length - 1].apr;
    }

    /// @notice Function to pause the contract (for emergency)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Function to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}
