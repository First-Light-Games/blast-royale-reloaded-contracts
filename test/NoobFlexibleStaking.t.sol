// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {NoobToken} from "../src/NoobToken.sol";
import {NoobFlexibleStaking} from "../src/NoobFlexibleStaking.sol";

contract NoobFlexibleStakingTest is Test {
    NoobToken token;
    NoobFlexibleStaking staking;
    address owner;
    address deployer;
    address randomPerson;
    address person1;
    address stakingOwner;

    function setUp() public {
        deployer = address(this);
        owner = address(0x111); // Set owner address
        randomPerson = address(0x112); // Set owner address
        stakingOwner = address(0x113); // Set owner address
        person1 = address(0x114); // Set owner address
        token = new NoobToken(owner);
        staking = new NoobFlexibleStaking(address(token), 15_000, stakingOwner);
    }

    function testStaking() public {
        vm.startPrank(owner);
        uint256 mintAmount = 100 * 10 ** token.decimals(); // Mint 100 tokens
        token.mint(person1, mintAmount);
        vm.warp(1680616584);
        vm.stopPrank();

        vm.startPrank(person1);
        token.approve(address(staking), mintAmount);
        staking.stake(mintAmount);
        uint256 rewards = staking.getClaimableRewards(person1);
        console.log(rewards);
        vm.warp(1680616584 + 90 days); // 3 months later...
        rewards = staking.getClaimableRewards(person1);
        console.log(rewards);
        vm.stopPrank();

        vm.startPrank(stakingOwner);
        staking.updateApr(5_000);
        vm.warp(1680616584 + 90 days + 30 days); // 4 months later...
        rewards = staking.getClaimableRewards(person1);
        console.log(rewards);
    }
}
