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
    uint256 stakeAmount = 100 * 1e18;
    uint256 initialBlockTimestamp = 1728461199;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        // Initialize token and staking contract
        token = new NoobToken(owner);

        vm.warp(initialBlockTimestamp - 1);

        // Deploy the mock price feed with an initial price of 1000 USD (1e8 precision for Chainlink)
        mockPriceFeed = new MockV3Aggregator(1000 * 1e8);

        // Initialize staking contract with mock price feed
        stakingContract = new NoobStaking(address(token), owner, initialBlockTimestamp, address(mockPriceFeed));

        // Mint tokens and approve staking contract
        vm.startPrank(owner);
        uint256 mintAmount = 1_000_000 * 10 ** token.decimals();
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
        assertEq(price, 1000 * 1e8, "Price should be 1000 USD");

        // Simulate price change
        vm.startPrank(owner);
        mockPriceFeed.setPrice(1200 * 1e8); // Set new price to 1200 USDf
        vm.stopPrank();

        // Check that the price from the mock is updated
        (, price,,,) = mockPriceFeed.latestRoundData();
        assertEq(price, 1200 * 1e8, "Price should now be 1200 USD");
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

    // Test claiming rewards for multiple staking
    function testClaimRewardsMultiple() public {
        vm.startPrank(user);
        vm.warp(initialBlockTimestamp);
        stakingContract.stakeFixed(stakeAmount);
        vm.stopPrank();
    }
}
