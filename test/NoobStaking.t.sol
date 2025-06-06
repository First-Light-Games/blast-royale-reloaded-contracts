// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {NoobStaking} from "../src/NoobStaking.sol";
import {NoobToken} from "../src/NoobToken.sol";
import {MockV3Aggregator} from "../src/mock/MockV3Aggregator.sol";

contract NoobStakingTest is Test {
    NoobToken token;
    NoobStaking stakingContract;
    MockV3Aggregator mockPriceFeed;  // Mock price feed instance
    address owner = address(0x1);
    address user = address(0x2);
    uint256 initialApr = 36500; // 10% APR daily equivalent for testing
    uint256 stakeAmount = 100 ether;
    uint256 initialBlockTimestamp = 1728461199;
    uint256 rewardLimit = 17820000 ether;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        vm.warp(initialBlockTimestamp - 1);

        // Initialize token and staking contract
        token = new NoobToken(owner);

        // Deploy the mock price feed with an initial price of 1000 USD (1e8 precision for Chainlink)
        mockPriceFeed = new MockV3Aggregator(1000 ether);

        // Initialize staking contract with mock price feed
        stakingContract = new NoobStaking(address(token), owner, initialBlockTimestamp, rewardLimit, address(mockPriceFeed));

        // Mint tokens and approve staking contract
        vm.startPrank(owner);
        uint256 mintAmount = 1_000_000 ether;
        token.mint(user, mintAmount); // Mint tokens for the user
        token.mint(address(stakingContract), mintAmount); // Mint tokens for staking rewards
        stakingContract.setFixedAPR(36500); // set APR 36.5% for testing
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), mintAmount); // Approve the staking contract
        vm.stopPrank();
    }

    // Test staking tokens with mock price feed
    function testStakeFixed() public {
        vm.warp(initialBlockTimestamp);
        userStake(stakeAmount, NoobStaking.StakeType.Fixed);

        // Check staking data
        (uint256 stakedAmount, , ) = stakingContract.userStakingInfo(user, NoobStaking.StakeType.Fixed, 0);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");

        vm.warp(initialBlockTimestamp + 30 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user, NoobStaking.StakeType.Fixed);
        assertEq(rewards, 3 ether, "Rewards should be 3 NOOB");

        vm.warp(initialBlockTimestamp + 170 days);
        rewards = stakingContract.getTotalClaimableRewards(user, NoobStaking.StakeType.Fixed);
        assertEq(rewards, 17 ether, "Rewards should be 17 NOOB");

        vm.warp(initialBlockTimestamp + 190 days);
        rewards = stakingContract.getTotalClaimableRewards(user, NoobStaking.StakeType.Fixed);
        assertEq(rewards, 18 ether, "Rewards should be 18 NOOB even if more than 180 days have passed");
    }

    // Test early withdraw for fixed staking
    function testEarlyWithdrawForFixed() public {
        vm.warp(initialBlockTimestamp);
        userStake(stakeAmount, NoobStaking.StakeType.Fixed);

        // Check staking data
        (uint256 stakedAmount, , ) = stakingContract.userStakingInfo(user, NoobStaking.StakeType.Fixed, 0);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");

        // calculate fixed staking rewards
        vm.warp(initialBlockTimestamp + 1 days);
        uint256 fixedRewards = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Fixed, 0);
        assertEq(fixedRewards, 0.1 ether, "Rewards should be 0.1 NOOB");

        // Claim rewards
        vm.startPrank(user);
        uint256 balance = token.balanceOf(user);
        stakingContract.withdrawFixed(0);

        // Check that the balance is correct
        uint256 newBalance = token.balanceOf(user);
        assertEq(newBalance, stakeAmount + balance, "Early withdraw doesn't give rewards");
        vm.stopPrank();
    }

    // Test claiming rewards multiple times to ensure rewards are cumulative
    function testFixedWithdraw() public {
        vm.warp(initialBlockTimestamp);
        userStake(stakeAmount, NoobStaking.StakeType.Fixed);

        uint256 initialBalance = token.balanceOf(user);

        // Warp time to simulate 15 days
        vm.warp(initialBlockTimestamp + 180 days);

        // Claim second set of rewards
        vm.startPrank(user);
        stakingContract.withdrawFixed(0);
        uint256 balanceAfterWithdraw = token.balanceOf(user);
        assertEq(balanceAfterWithdraw, initialBalance + stakeAmount + 18 ether, "Balance after second claim should match");
        vm.stopPrank();
    }

    // Test lucky staking functionality early withdraw
    function testLuckyStakeAndRewards() public {
        vm.warp(initialBlockTimestamp);
        userStake(stakeAmount, NoobStaking.StakeType.Lucky);

        // Check the staking data
        (uint256 stakedAmount, ,uint256 apr) = stakingContract.userStakingInfo(user, NoobStaking.StakeType.Lucky, 0);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");
        assertGt(apr, 0, "APR should be set based on random selection");

        // Warp time to simulate 10 days of staking
        vm.warp(initialBlockTimestamp + 100 days);
        uint256 calculatedRewards = stakeAmount * 100 days * apr / 365 days / 100 / 1000;
        uint256 rewards = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Lucky, 0);
        assertApproxEqAbs(rewards, calculatedRewards, 100, "Rewards should be calculated correctly for lucky staking");

        // Withdraw and claim the rewards
        vm.warp(initialBlockTimestamp + 180 days);
        vm.startPrank(user);
        uint256 balanceBeforeWithdraw = token.balanceOf(user);
        rewards = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Lucky, 0);
        stakingContract.withdrawLucky(0);
        uint256 balanceAfterWithdraw = token.balanceOf(user);
        assertEq(balanceAfterWithdraw, balanceBeforeWithdraw + stakeAmount + rewards, "Balance after withdraw should match");
        vm.stopPrank();
    }

    // Test toggling staking availability
    function testToggleStaking() public {
        vm.startPrank(owner);
        vm.warp(initialBlockTimestamp);
        // Disable both staking options
        stakingContract.toggleFixedStaking(false);
        stakingContract.toggleLuckyStaking(false);
        vm.stopPrank();

        // Attempt to stake, which should revert
        vm.startPrank(user);
        vm.expectRevert("Fixed staking is disabled");
        stakingContract.stakeFixed(stakeAmount);

        vm.expectRevert("Lucky staking is disabled");
        stakingContract.stakeLucky(stakeAmount);
        vm.stopPrank();

        vm.startPrank(owner);
        // Re-enable both staking options
        stakingContract.toggleFixedStaking(true);
        stakingContract.toggleLuckyStaking(true);
        vm.stopPrank();

        // Attempt to stake again, which should now succeed
        vm.startPrank(user);
        stakingContract.stakeFixed(stakeAmount);
        stakingContract.stakeLucky(stakeAmount);
        vm.stopPrank();
    }

    // Test reaching total rewards limit
    function testTotalRewardsLimit() public {
        vm.warp(initialBlockTimestamp);

        mintTokens(user, 105_000_000 ether);

        // Stake multiple times to reach near the rewards limit
        for (uint256 i = 0; i < 33; i++) {
            userStake(3_000_000 ether, NoobStaking.StakeType.Fixed);
        }

        uint256 calculatedRewardsLimit = 3_000_000 ether * 180 days * initialApr / 365 days / 100 / 1000 * 33;
        // Check that the total rewards approach the limit
        uint256 totalRewards = stakingContract.totalRewards();
        assertEq(totalRewards, rewardLimit, "Total rewards should be below the limit");

        // Additional staking should revert once the limit is reached
        vm.startPrank(user);
        token.approve(address(stakingContract), 3_000_000 ether);
        vm.expectRevert("Staking rewards limit reached");
        stakingContract.stakeFixed(3_000_000 ether);
        vm.stopPrank();
    }

    function userStake(uint256 _amount, NoobStaking.StakeType _type) public {
        vm.startPrank(user);
        token.approve(address(stakingContract), _amount);
        if (_type == NoobStaking.StakeType.Fixed) {
            stakingContract.stakeFixed(_amount);
        } else {
            stakingContract.stakeLucky(_amount);
        }
        vm.stopPrank();
    }

    function mintTokens(address _user, uint256 amount) public {
        vm.startPrank(owner);
        token.mint(address(stakingContract), amount);
        token.mint(_user, amount);
        vm.stopPrank();
    }
}
