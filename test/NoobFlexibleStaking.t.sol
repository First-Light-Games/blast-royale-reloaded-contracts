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
    uint256 initialApr = 36_500; // 36.5% APR
    uint256 stakeAmount = 100 ether;
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

    // https://docs.google.com/spreadsheets/d/1rzQ9kZlOsznrd7ghnvVetDbfEmccSgEochOuBcBsAyw/edit?gid=412342782#gid=412342782
    function testScenario1() public {
        vm.warp(initialBlockTimestamp);

        userStake(100 ether);
        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 1 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.1 ether, "Rewards amount should match");
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 100 ether, "Staked amount should match");
        userStake(100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 2 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.3 ether, "Rewards amount should match");
        amount= stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 200 ether, "Staked amount should match");
        userStake(100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 3 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.6 ether, "Rewards amount should match");
        amount= stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 300 ether, "Staked amount should match");
        userStake(100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(initialBlockTimestamp + 4 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 1 ether, "Rewards amount should match");
        amount= stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 400 ether, "Staked amount should match");
        vm.stopPrank();
    }

    // https://docs.google.com/spreadsheets/d/1rzQ9kZlOsznrd7ghnvVetDbfEmccSgEochOuBcBsAyw/edit?gid=11554102#gid=11554102
    function testScenario2() public {
        vm.warp(initialBlockTimestamp);

        userStake(100 ether);
        vm.warp(initialBlockTimestamp + 2 days);
        userStake(1000 ether);

        vm.warp(initialBlockTimestamp + 3 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 1.3 ether, "Staked amount should match");
    }

    // https://docs.google.com/spreadsheets/d/1rzQ9kZlOsznrd7ghnvVetDbfEmccSgEochOuBcBsAyw/edit?gid=1151639323#gid=1151639323
    function testScenarioMultiple() public {
        vm.warp(initialBlockTimestamp);

        vm.startPrank(owner);
        token.mint(user, 100000000 ether);
        token.mint(address(stakingContract), 100000000 ether); // for staking rewards
        vm.stopPrank();

        vm.startPrank(user);

        // Initial staking of 100 NOOB tokens
        token.approve(address(stakingContract), 100000000000000 ether);
        stakingContract.stake(100 ether);

        // Forward time by 1 day and add more stakes each day, testing APR changes and further actions
        for (uint256 day = 1; day <= 9; day++) {
            vm.warp(initialBlockTimestamp + day * 24 hours);
            uint256 rewards = stakingContract.getTotalClaimableRewards(user);
            assertEq(rewards, getRewardValueForScenario3(day), "Rewards should match");

            vm.startPrank(owner);
            // Simulate APR change by the admin
            if (day == 3) {
                stakingContract.updateApr(365_000);  // Increase APR to 365%
            } else if (day == 5) {
                stakingContract.updateApr(3650);   // Decrease APR back to 3.65%
            }
            vm.stopPrank();

            vm.startPrank(user);

            // Optionally, add unstaking and restaking to simulate user actions
            if (day == 2) {
                stakingContract.unstake(0);
                stakingContract.stake(1000 ether);   // Stake again with 100 NOOB
            }
        }

        vm.stopPrank();
    }

    // https://docs.google.com/spreadsheets/d/1rzQ9kZlOsznrd7ghnvVetDbfEmccSgEochOuBcBsAyw/edit?gid=571144160#gid=571144160
    function testClaimAndStake() public {
        vm.warp(initialBlockTimestamp);
        userStake(100 ether);

        vm.warp(initialBlockTimestamp + 5 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.5 ether, "Rewards should match");

        vm.startPrank(user);
        stakingContract.claimAndStake(0);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0, "Rewards should be 0 after claimAndStake");
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 100.5 ether, "Rewards should be added to stakedAmount");

        vm.warp(initialBlockTimestamp + 10 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.5025 ether, "Rewards should match");
        vm.stopPrank();
    }

    function testUnstakeAndStake() public {
        vm.warp(initialBlockTimestamp);

        mintTokens(user, 100000000 ether);

        userStake(100 ether);

        vm.warp(initialBlockTimestamp + 5 days);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0.5 ether, "Rewards should match");

        vm.startPrank(user);
        stakingContract.unstake(0);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 0, "Rewards should be 0 after claimAndStake");
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        assertEq(amount, 0, "Stake amount should be 0 after unstake");

        userStake(1000 ether);
        vm.warp(initialBlockTimestamp + 6 days);
        rewards = stakingContract.getTotalClaimableRewards(user);
        assertEq(rewards, 1 ether, "Day 1 Rewards should be 1 NOOB");
        vm.stopPrank();
    }

    function testStakeAndChangeAprAndclaimAndStake() public {
        vm.warp(1680616584);

        mintTokens(user, 100000000 ether);

        userStake(100 ether);

        // 5 days pass
        vm.warp(1680616584 + 5 days);

        // Update APR to 3.65% from 36.5%
        vm.startPrank(owner);
        stakingContract.updateApr(3650);  // Decrease APR to 3.65%
        vm.stopPrank();

        // 10 days pass
        vm.warp(1680616584 + 10 days);

        vm.startPrank(user);
        uint256 rewards = stakingContract.getTotalClaimableRewards(user);
        console.log("Rewards after decreasing apr:", rewards);
        stakingContract.claimAndStake(0);
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        console.log("Staked Amount", amount);
        rewards = stakingContract.getTotalClaimableRewards(user);
        console.log("Rewards after claimAndStake:", rewards);
        vm.stopPrank();
    }

     function testCumulativeStakes() public {
        vm.warp(1728319899);

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 1 days);
        assertEq(stakingContract.getTotalClaimableRewards(user), 100000000000000000, "Reward should be 100000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 2 days);
        assertEq(stakingContract.getTotalClaimableRewards(user), 300000000000000000, "Reward should be 300000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();
    }

    // Test claiming rewards
    function testClaimRewards() public {
        vm.startPrank(user);
        token.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);
        uint256 rewards;
        vm.warp(block.timestamp + 90 days); // 3 months later...
        rewards = stakingContract.getTotalClaimableRewards(user);
        console.log(rewards);
        vm.stopPrank();

        vm.startPrank(owner);
        stakingContract.updateApr(5_000);
        vm.warp(block.timestamp + 90 days + 30 days); // 4 months later...
        rewards = stakingContract.getTotalClaimableRewards(user);
        console.log(rewards);
        vm.stopPrank();
    }

    // Test updating APR by the owner
    function testUpdateApr() public {
        uint256 newApr = 18_000; // 18%

        vm.startPrank(owner);
        stakingContract.updateApr(newApr);

        uint256 currentApr = stakingContract.getCurrentApr();
        assertEq(currentApr, newApr, "APR should be updated to the new value");
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
        vm.stopPrank();
    }

    /*Let's say we have flexible staking, 10% per day.
    I put 100 tokens in day 1.
    Then i put 100 tokens on day 2.
    Then i put 100 tokens on day 3.
    What's expected to happen is:
    On day 1 i'd get 10 tokens, so i have 110 tokens staked
    On day 2 i get 21 tokens, so i have 231 tokens staked
    On day 3 i get 33 tokens, so i get 364 tokens staked*/

    function testExampleScenario() public {
        vm.warp(1728319899);

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 1 days);
        assertEq(stakingContract.getTotalClaimableRewards(user), 100000000000000000, "Reward should be 100000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        uint256 amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 2 days);
        assertEq(stakingContract.getTotalClaimableRewards(user), 300000000000000000, "Reward should be 300000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 3 days);
        assertEq(stakingContract.getTotalClaimableRewards(user), 600000000000000000, "Reward should be 600000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 4 days);
        assertEq(stakingContract.getTotalClaimableRewards(user), 1000000000000000000, "Reward should be 1000000000000000000 with a 36.5% apr");
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        vm.stopPrank();
        vm.startPrank(owner);
        stakingContract.updateApr(15_000);
        vm.stopPrank();
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether);
        vm.warp(1728319899 + 5 days);
        console.log("rewards", stakingContract.getTotalClaimableRewards(user));
        amount = stakingContract.getTotalStakedAmount(user);
        console.log("stakeAmount", amount);
        assertEq(stakingContract.getTotalClaimableRewards(user), 1205479452054794520, "Reward should be 1205479452054794520 with a 15% apr on day 5");
        vm.stopPrank();
    }

    function userStake(uint256 amount) public {
        vm.startPrank(user);
        token.approve(address(stakingContract), amount);
        stakingContract.stake(amount);
        vm.stopPrank();
    }

    function mintTokens(address user, uint256 amount) public {
        vm.startPrank(owner);
        token.mint(address(stakingContract), amount);
        token.mint(user, amount);
        vm.stopPrank();
    }

    function getRewardValueForScenario3(uint256 day) public returns (uint256) {
        uint256 rewardValue = 0;
        if (day == 1) {
            rewardValue = 0.1 ether;
        } else if (day == 2) {
            rewardValue = 0.2 ether;
        } else if (day == 3) {
            rewardValue = 1 ether;
        } else if (day == 4) {
            rewardValue = 11 ether;
        } else if (day == 5) {
            rewardValue = 21 ether;
        } else if (day == 6) {
            rewardValue = 21.1 ether;
        } else if (day == 7) {
            rewardValue = 21.2 ether;
        } else if (day == 8) {
            rewardValue = 21.3 ether;
        } else if (day == 9) {
            rewardValue = 21.4 ether;
        }
        return rewardValue;
    }
}
