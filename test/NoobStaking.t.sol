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
    uint256 rewardLimit = 40 * 1_000_000 ether;

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
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), mintAmount); // Approve the staking contract
        vm.stopPrank();
    }

    // Test staking tokens with mock price feed
    function testStakeFixed() public {
        vm.startPrank(user);

        vm.warp(initialBlockTimestamp);

        // Stake tokens and check staking status
        stakingContract.stakeFixed(stakeAmount);
        vm.stopPrank();

        // Check staking data
        (uint256 stakedAmount, , ) = stakingContract.userStakingInfo(user, NoobStaking.StakeType.Fixed, 0);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");

        // Check that the price from the mock is correct
        (, int256 price,,,) = mockPriceFeed.latestRoundData();
        assertEq(price, 1000 ether, "Price should be 1000 USD");

        // Simulate price change
        vm.startPrank(owner);
        mockPriceFeed.setPrice(1200 ether); // Set new price to 1200 USDf
        vm.stopPrank();

        // Check that the price from the mock is updated
        (, price,,,) = mockPriceFeed.latestRoundData();
        assertEq(price, 1200 ether, "Price should now be 1200 USD");
    }

    // Test claiming rewards for fixed staking
    function testClaimRewards() public {
        vm.startPrank(user);

        vm.warp(initialBlockTimestamp);

        // Stake tokens and check staking status
        stakingContract.stakeFixed(stakeAmount);

        // Check staking data
        (uint256 stakedAmount, , ) = stakingContract.userStakingInfo(user, NoobStaking.StakeType.Fixed, 0);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");

        // calculate fixed staking rewards
        vm.warp(initialBlockTimestamp + 1 days);
        uint256 fixedRewards = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Fixed, 0);
        console.log('reward1', fixedRewards);

        // Claim rewards
        uint256 balance = token.balanceOf(user);
        stakingContract.withdrawFixed(0);

        // Check that the balance is correct
        uint256 newBalance = token.balanceOf(user);
        assertEq(newBalance, stakeAmount + balance, "There shouldn't be any change in the balance");
        vm.stopPrank();
    }

    // Test claiming rewards multiple times to ensure rewards are cumulative
    function testClaimRewardsMultipleWithAssertions() public {
        vm.startPrank(user);
        vm.warp(initialBlockTimestamp);

        uint256 initialBalance = token.balanceOf(user);

        // Stake tokens
        stakingContract.stakeFixed(stakeAmount);

        // Warp time to simulate 15 days
        vm.warp(initialBlockTimestamp + 15 days);
        uint256 rewards1 = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Fixed, 0);
        assertApproxEqRel(rewards1, (stakeAmount * 80_000 * 15 days) / 365 days / 1_000 / 100, 1e12, "Rewards after 15 days should be correct");

        // Warp time to simulate 180 days
        vm.warp(initialBlockTimestamp + 180 days);
        uint256 rewards2 = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Fixed, 0);
        assertApproxEqRel(rewards2, (stakeAmount * 80_000 * 180 days) / 365 days / 1_000 / 100, 1e12, "Rewards after additional 180 days should be correct");

        // Claim second set of rewards
        stakingContract.withdrawFixed(0);
        uint256 balanceAfterClaim = token.balanceOf(user);
        assertEq(balanceAfterClaim, initialBalance + rewards2, "Balance after second claim should match");

        vm.stopPrank();
    }

    // Test cumulative rewards calculation
    function testCumulativeRewards() public {
        vm.startPrank(user);
        vm.warp(initialBlockTimestamp);

        // Stake tokens
        stakingContract.stakeFixed(stakeAmount);

        // Warp time to simulate half of the fixed lock period
        vm.warp(initialBlockTimestamp + 90 days);

        uint256 claimableRewards1 = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Fixed, 0);
        uint256 expectedRewards1 = (stakeAmount * 80_000 * 90 days) / 365 days / 1_000 / 100;
        assertApproxEqRel(claimableRewards1, expectedRewards1, 1e12, "Rewards after 90 days should be correct");

        // Warp time to simulate the full lock period (180 days total)
        vm.warp(initialBlockTimestamp + 180 days);

        uint256 claimableRewards2 = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Fixed, 0);
        uint256 expectedRewards2 = (stakeAmount * 80_000 * 180 days) / 365 days / 1_000 / 100;
        assertApproxEqRel(claimableRewards2, expectedRewards2, 1e12, "Rewards after 180 days should be correct");

        vm.stopPrank();
    }

    // Test lucky staking functionality early withdraw
    function testLuckyStakeAndRewards() public {
        vm.startPrank(user);
        vm.warp(initialBlockTimestamp);

        // Stake tokens in lucky staking
        stakingContract.stakeLucky(stakeAmount);

        // Check the staking data
        (uint256 stakedAmount, ,uint256 apr) = stakingContract.userStakingInfo(user, NoobStaking.StakeType.Lucky, 0);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");
        assertGt(apr, 0, "APR should be set based on random selection");

        // Warp time to simulate 10 days of staking
        vm.warp(initialBlockTimestamp + 10 days);
        uint256 rewards = stakingContract.getClaimableRewards(user, NoobStaking.StakeType.Lucky, 0);
        assertGt(rewards, 0, "Rewards should be calculated correctly for lucky staking");

        // Withdraw and claim the rewards
        vm.warp(initialBlockTimestamp + 180 days);
        uint256 balanceBeforeWithdraw = token.balanceOf(user);
        stakingContract.withdrawLucky(0);
        uint256 balanceAfterWithdraw = token.balanceOf(user);
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

        // Mint tokens and approve staking contract
        vm.startPrank(owner);
        uint256 mintAmount = 105_000_000 ether;
        token.mint(user, mintAmount); // Mint tokens for the user
        token.mint(address(stakingContract), 40 * 1_000_000 ether); // Mint tokens for staking rewards
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 105_000_000 ether); // Approve the staking contract
        // Stake multiple times to reach near the rewards limit
        for (uint256 i = 0; i < 33; i++) {
            stakingContract.stakeFixed(3_000_000 ether);
        }

        // Check that the total rewards approach the limit
        uint256 totalRewards = stakingContract.totalRewards();
        assertLt(totalRewards, rewardLimit, "Total rewards should be below the limit");

        // Additional staking should revert once the limit is reached
        vm.expectRevert("Staking rewards limit reached");
        stakingContract.stakeFixed(3_000_000 ether);
        vm.stopPrank();
    }
}
