// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {NoobToken} from "../src/NoobToken.sol";
import {NoobFlexibleStaking} from "../src/NoobFlexibleStaking.sol";

contract NoobFlexibleStakingTest is Test {
    NoobToken token;
    NoobFlexibleStaking stakingContract;
    address owner = address(0x1);
    address user = address(0x2);
    uint256 initialApr = 15_000; // 15% APR
    uint256 stakeAmount = 100 * 1e18;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        token = new NoobToken(owner);
        stakingContract = new NoobFlexibleStaking(address(token), initialApr, owner);

        // Label addresses for better logging
        vm.label(owner, "Owner");
        vm.label(user, "User");

        // Set the block time to a constant known value & deploy $NOOB
        vm.startPrank(owner);
        uint256 mintAmount = 1_000_000 * 10 ** token.decimals(); // Mint 1_000_000 tokens
        token.mint(user, mintAmount);
        vm.warp(1680616584);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(stakingContract), mintAmount);
        vm.stopPrank();
    }

    // Test staking function
    function testStakeTokens() public {
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
        assertGt(userBalance, 1e18, "User balance should be greater after unstaking");
    }

    // Test updating APR by the owner
    function testUpdateApr() public {
        uint256 newApr = 18_000; // 18%

        vm.startPrank(owner);
        stakingContract.updateApr(newApr);

        uint256 currentApr = stakingContract.getCurrentApr();
        assertEq(currentApr, newApr, "APR should be updated to the new value");
    }

    // Test only owner can update APR
    function testOnlyOwnerCanUpdateApr() public {
        uint256 newApr = 20_000; // 20%

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user));
        stakingContract.updateApr(newApr); // This should revert since the caller is not the owner
    }

    // Test claiming and staking rewards (compound)
    function testClaimAndStakeRewards() public {
        uint256 stakeAmount = 100 * 1e18; // 100 NOOB

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
        assertGt(stakedAmount, stakeAmount, "Staked amount should increase after claiming and staking rewards");
    }
}
