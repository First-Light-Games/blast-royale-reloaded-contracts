// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {NoobFlexibleStaking} from "../src/NoobFlexibleStaking.sol";
import {NoobToken} from "../src/NoobToken.sol";

contract NoobFlexibleStakingTest is Test {
    NoobToken token;
    NoobFlexibleStaking stakingContract;
    address owner = address(0x1);
    address user = address(0x2);
    uint256 initialApr = 36_500; // 15% APR
    uint256 stakeAmount = 100 * 1e18;
    uint256 tgeStart = 1680616584;
    uint256 initialBlockTimestamp = 1680616584;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        vm.warp(initialBlockTimestamp);

        token = new NoobToken(owner);
        stakingContract = new NoobFlexibleStaking(
            address(token),
            initialApr,
            owner,
            tgeStart
        );

        // Label addresses for better logging
        vm.label(owner, "Owner");
        vm.label(user, "User");

        // Set the block time to a constant known value & deploy $NOOB
        vm.startPrank(owner);
        uint256 mintAmount = 1_000_000 * 10 ** token.decimals(); // Mint 1_000_000 tokens
        token.mint(user, mintAmount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), mintAmount);
        vm.stopPrank();
    }

    /*function testExampleScenarioMultiple() public {
        vm.warp(1680616584);

        vm.startPrank(owner);
        token.mint(user, 100000000 ether);
        token.mint(address(stakingContract), 100000000 ether);
        vm.stopPrank();

        vm.startPrank(user);

        // Initial staking of 100 NOOB tokens
        uint256 amount = 100 ether;
        token.approve(address(stakingContract), 100000000000000 ether);
        stakingContract.stake(amount);

        // Forward time by 1 day and add more stakes each day, testing APR changes and further actions
        for (uint256 day = 1; day <= 10; day++) {
            vm.warp(1680616584 + day * 24 hours);
            uint256 rewards = stakingContract.getClaimableRewards(user);
            console.log("Day", day, "Rewards:", rewards);

            vm.startPrank(owner);
            // Simulate APR change by the admin
            if (day == 3) {
                stakingContract.updateApr(25_000);  // Increase APR to 25%
            } else if (day == 5) {
                stakingContract.updateApr(5_000);   // Decrease APR back to 5%
            }
            vm.stopPrank();

            vm.startPrank(user);

            // Optionally, add unstaking and restaking to simulate user actions
            if (day == 2) {
                stakingContract.unstake();  // Unstake part of the stake on day 2
                stakingContract.stake(100 ether);   // Stake again with 100 NOOB
            }
        }

        vm.stopPrank();
    }

    function testClaimAndStake() public {
        vm.warp(1680616584);
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.stopPrank();

        vm.warp(1680616584 + 5 days);
        uint256 rewards = stakingContract.getClaimableRewards(user);
        console.log("Day 5 Rewards:", rewards);

        vm.startPrank(user);
        stakingContract.claimAndStake();
        rewards = stakingContract.getClaimableRewards(user);
        console.log("Rewards after claimAndStake:", rewards);
        (uint256 amount, , , ) = stakingContract.userStakes(user);
        console.log("Staked Amount", amount);

        vm.warp(1680616584 + 6 days);
        rewards = stakingContract.getClaimableRewards(user);
        console.log("Day 6 Rewards:", rewards);
        vm.stopPrank();
    }

    function testUnstakeAndStake() public {
        vm.warp(1680616584);

        vm.startPrank(owner);
        token.mint(user, 100000000 ether);
        token.mint(address(stakingContract), 100000000 ether);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.stopPrank();

        vm.warp(1680616584 + 5 days);
        uint256 rewards = stakingContract.getClaimableRewards(user);
        console.log("Day 5 Rewards:", rewards);

        vm.startPrank(user);
        stakingContract.unstake();
        rewards = stakingContract.getClaimableRewards(user);
        console.log("Rewards after unstakeAndStake:", rewards);
        (uint256 amount, , , ) = stakingContract.userStakes(user);
        console.log("Staked Amount", amount);

        vm.warp(1680616584 + 6 days);
        rewards = stakingContract.getClaimableRewards(user);
        console.log("Day 6 Rewards:", rewards);
        vm.stopPrank();
    }

    function testStakeAndChangeAprAndclaimAndStake() public {
        vm.warp(1680616584);

        vm.startPrank(owner);
        token.mint(user, 100000000 ether);
        token.mint(address(stakingContract), 100000000 ether);
        vm.stopPrank();

        // stake
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.stopPrank();

        // 5 days pass
        vm.warp(1680616584 + 5 days);

        // Update APR to 3.65% from 36.5%
        vm.startPrank(owner);
        stakingContract.updateApr(3650);  // Decrease APR to 3.65%
        vm.stopPrank();

        // 10 days pass
        vm.warp(1680616584 + 10 days);

        vm.startPrank(user);
        uint256 rewards = stakingContract.getClaimableRewards(user);
        console.log("Rewards after decreasing apr:", rewards);
        stakingContract.claimAndStake();
        (uint256 amount, , , ) = stakingContract.userStakes(user);
        console.log("Staked Amount", amount);
        rewards = stakingContract.getClaimableRewards(user);
        console.log("Rewards after claimAndStake:", rewards);
        vm.stopPrank();
    }*/

    // https://docs.google.com/spreadsheets/d/1rzQ9kZlOsznrd7ghnvVetDbfEmccSgEochOuBcBsAyw/edit?gid=412342782#gid=412342782
    function testScenario1() public {
        vm.warp(initialBlockTimestamp);

        vm.startPrank(user);
        token.approve(address(stakingContract), 10000 ether);
        stakingContract.stake(100 ether);
        vm.warp(initialBlockTimestamp + 1 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.1 ether, "Staked amount should match");
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 100 ether, "Staked amount should match");
        stakingContract.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 2 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.3 ether, "Staked amount should match");
        amount= stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 200 ether, "Staked amount should match");
        stakingContract.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 3 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.6 ether, "Staked amount should match");
        amount= stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 300 ether, "Staked amount should match");
        stakingContract.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 4 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 1 ether, "Staked amount should match");
        amount= stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 400 ether, "Staked amount should match");
        vm.stopPrank();
    }

    // https://docs.google.com/spreadsheets/d/1rzQ9kZlOsznrd7ghnvVetDbfEmccSgEochOuBcBsAyw/edit?gid=11554102#gid=11554102
    function testScenario2() public {
        vm.warp(initialBlockTimestamp);

        vm.startPrank(user);
        token.approve(address(stakingContract), 10000 ether);
        stakingContract.stake(100 ether);
        vm.warp(initialBlockTimestamp + 2 days);
        stakingContract.stake(1000 ether);

        vm.warp(initialBlockTimestamp + 3 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 1.3 ether, "Staked amount should match");

        vm.stopPrank();
    }

    // Test staking function
    /*function testStakeTokens() public {
        vm.startPrank(owner);
        token.mint(user, stakeAmount);
        vm.stopPrank();

        vm.startPrank(user); // Set the next call to be made by 'user'
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount); // Stake 100 NOOB
        vm.stopPrank();

        // Check the user's staking balance after staking
        (uint256 stakedAmount, , , ) = stakingContract.userStakes(user);
        assertEq(stakedAmount, stakeAmount, "Staked amount should match");
    }

    // Test claiming rewards
    function testClaimRewards() public {
        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);
        uint256 rewards;
        vm.warp(block.timestamp + 90 days); // 3 months later...
        rewards = stakingContract.getClaimableRewards(user);
        console.log(rewards);
        vm.stopPrank();

        vm.startPrank(owner);
        stakingContract.updateApr(5_000);
        vm.warp(block.timestamp + 90 days + 30 days); // 4 months later...
        rewards = stakingContract.getClaimableRewards(user);
        console.log(rewards);
        vm.stopPrank();
    }

    // Test claiming rewards after updating APR
    function testClaimRewardsAfterUpdatingApr() public {
        vm.warp(1);
        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);
        uint256 rewards;
        vm.warp(1 + 10 days); // 10 days later...
        rewards = stakingContract.getClaimableRewards(user);
        console.log(rewards);
        vm.stopPrank();

        vm.startPrank(owner);
        stakingContract.updateApr(5_000); // Update APR to 5%
        vm.warp(1 + 20 days); // 20 days later...
        rewards = stakingContract.getClaimableRewards(user);
        console.log(rewards);
        vm.stopPrank();
    }

    // Test unstaking tokens
    function testUnstakeTokens() public {
        vm.startPrank(owner);
        token.mint(address(stakingContract), 100000 * 1e18); // mint $NOOB to staking contract for rewards
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount); // Stake 100 NOOB
        vm.stopPrank();

        // Fast forward 1 year to accumulate rewards
        vm.warp(block.timestamp + 365 days);

        // Unstake tokens
        vm.startPrank(user);
        stakingContract.unstake();
        vm.stopPrank();

        // Check user's balance after unstaking
        uint256 userBalance = token.balanceOf(user);
        assertGt(
            userBalance,
            1e18,
            "User balance should be greater after unstaking"
        );
    }

    // Test updating APR by the owner
    function testUpdateApr() public {
        uint256 newApr = 18_000; // 18%

        vm.startPrank(owner);
        stakingContract.updateApr(newApr);

        uint256 currentApr = stakingContract.getCurrentApr();
        assertEq(currentApr, newApr, "APR should be updated to the new value");
    }

    *//*Let's say we have flexible staking, 10% per day.
    I put 100 tokens in day 1.
    Then i put 100 tokens on day 2.
    Then i put 100 tokens on day 3.
    What's expected to happen is:
    On day 1 i'd get 10 tokens, so i have 110 tokens staked
    On day 2 i get 21 tokens, so i have 231 tokens staked
    On day 3 i get 33 tokens, so i get 364 tokens staked*//*

    function testExampleScenario() public {
        vm.warp(1728319899);

        // vm.startPrank(owner);
        // stakingContract.updateApr(36500); // 10% per day
        // vm.stopPrank();
        // vm.warp(1728319899);
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 * 1e18);
        stakingContract.stake(100 * 1e18);
        vm.warp(1728319899 + 1 days);
        assertEq(stakingContract.getClaimableRewards(user), 100000000000000000, "Reward should be 100000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getClaimableRewards(user));
        (uint256 amount, , , ) = stakingContract.userStakes(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 * 1e18);
        stakingContract.stake(100 * 1e18);
        vm.warp(1728319899 + 2 days);
        assertEq(stakingContract.getClaimableRewards(user), 300000000000000000, "Reward should be 300000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getClaimableRewards(user));
        (amount, , , ) = stakingContract.userStakes(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 * 1e18);
        stakingContract.stake(100 * 1e18);
        vm.warp(1728319899 + 3 days);
        assertEq(stakingContract.getClaimableRewards(user), 600000000000000000, "Reward should be 600000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getClaimableRewards(user));
        (amount, , , ) = stakingContract.userStakes(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 * 1e18);
        stakingContract.stake(100 * 1e18);
        vm.warp(1728319899 + 4 days);
        assertEq(stakingContract.getClaimableRewards(user), 1000000000000000000, "Reward should be 1000000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getClaimableRewards(user));
        (amount, , , ) = stakingContract.userStakes(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();
        vm.startPrank(owner);
        stakingContract.updateApr(15_000);
        vm.stopPrank();
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 * 1e18);
        stakingContract.stake(100 * 1e18);
        vm.warp(1728319899 + 5 days);
        console.log("rewards", stakingContract.getClaimableRewards(user));
        (amount, , , ) = stakingContract.userStakes(user);
        console.log("stakeAmount", amount);
        assertEq(stakingContract.getClaimableRewards(user), 1205479452054794520, "Reward should be 1205479452054794520 with a 15% apr on day 5");
        vm.stopPrank();
    }

    // Test only owner can update APR
    function testOnlyOwnerCanUpdateApr() public {
        uint256 newApr = 20_000; // 20%

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        stakingContract.updateApr(newApr); // This should revert since the caller is not the owner
    }

    // Test claiming and staking rewards (compound)
    function testClaimAndStakeRewards() public {
        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount); // Stake 100 NOOB

        // Fast forward 1 year to accumulate rewards
        vm.warp(block.timestamp + 365 days);

        uint256 rewardsBefore = stakingContract.getClaimableRewards(user);
        assertGt(rewardsBefore, 0, "Rewards should be greater than zero");

        // Compound rewards by claiming and staking
        vm.startPrank(user);
        stakingContract.claimAndStake();

        (uint256 stakedAmount, , , ) = stakingContract.userStakes(user);
        assertGt(
            stakedAmount,
            stakeAmount,
            "Staked amount should increase after claiming and staking rewards"
        );
    }

    // Test multi-claims with APR change in the middle
    function testMultiClaimsWithAprUpdate() public {
        vm.startPrank(owner);
        token.mint(address(stakingContract), 1_000_000 * 1e18); // mint $NOOB to staking contract for rewards
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);

        // Move time forward by 30 days
        vm.warp(block.timestamp + 30 days);

        // Claim rewards for the first period
        uint256 rewardsBeforeAprChange = stakingContract.getClaimableRewards(
            user
        );

        // Assert rewards are correct before APR change
        assertGt(
            rewardsBeforeAprChange,
            0,
            "First claimable rewards should be greater than zero"
        );

        // Update APR by the owner
        vm.startPrank(owner);
        stakingContract.updateApr(5000); // Change APR to 5%
        vm.stopPrank();

        // Move time forward by another 30 days
        vm.warp(block.timestamp + 30 days + 30 days);

        // Claim rewards after APR change
        vm.startPrank(user);
        uint256 rewardsAfterAprChange = stakingContract.getClaimableRewards(
            user
        );
        stakingContract.claimStakeRewards();

        // Assert that rewards are calculated correctly after APR change
        assertGt(
            rewardsAfterAprChange,
            0,
            "Rewards after APR change should be greater than zero"
        );

        // Assert that rewards are lower after the APR update
        assertGt(
            rewardsAfterAprChange,
            rewardsBeforeAprChange,
            "Rewards after APR change should be greater than before"
        );
    }

    // Test cumulative rewards vs only staked amount
    function testCumulativeRewardsOrOnlyStakedAmount() public {
        vm.startPrank(owner);
        token.mint(address(stakingContract), 100000 * 1e18); // mint $NOOB to staking contract for rewards
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);

        // Move time forward by 30 days
        vm.warp(block.timestamp + 30 days);

        // Claim rewards
        uint256 rewardsBeforeCompound = stakingContract.getClaimableRewards(
            user
        );
        stakingContract.claimStakeRewards();

        // Assert rewards are correct and then compound by staking them
        assertGt(
            rewardsBeforeCompound,
            0,
            "Claimable rewards should be greater than zero"
        );

        // Move time forward by 30 days
        vm.warp(block.timestamp + 31 days);

        (uint256 totalStakedBeforeCompound, , , ) = stakingContract.userStakes(
            user
        );
        stakingContract.claimAndStake();

        (uint256 totalStakedAfterCompound, , , ) = stakingContract.userStakes(
            user
        );
        assertGt(
            totalStakedAfterCompound,
            totalStakedBeforeCompound,
            "Staked amount should increase after compounding"
        );

        // Move time forward and ensure rewards are calculated based on the new staked amount (including previous rewards)
        vm.warp(block.timestamp + 61 days);
        uint256 rewardsAfterCompound = stakingContract.getClaimableRewards(
            user
        );

        // Check if cumulative rewards are considered for future rewards calculation
        assertGt(
            rewardsAfterCompound,
            rewardsBeforeCompound,
            "Rewards after compounding should be greater than before"
        );
    }

    // Test APR change mid-stake without claiming
    function testAprUpdateMidStakeWithoutClaiming() public {
        vm.startPrank(owner);
        token.mint(address(stakingContract), 100000 * 1e18); // mint $NOOB to staking contract for rewards
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);

        // Move time forward by 15 days, APR is still the same
        vm.warp(block.timestamp + 15 days);
        uint256 rewardsBeforeAprChange = stakingContract.getClaimableRewards(
            user
        );

        // Update APR mid-stake
        vm.startPrank(owner);
        stakingContract.updateApr(20000); // Update APR to 20%
        vm.stopPrank();

        // Move time forward by another 15 days
        vm.warp(block.timestamp + 30 days);
        uint256 rewardsAfterAprChange = stakingContract.getClaimableRewards(
            user
        );

        // Assert that rewards are higher after the APR update
        assertGt(
            rewardsAfterAprChange,
            rewardsBeforeAprChange,
            "Rewards should increase after APR update"
        );
    }*/
}
