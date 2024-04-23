// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError, console} from "forge-std/Test.sol";
import {NoobToken} from "../src/NoobToken.sol";

contract NoobTokenTest is Test {
    NoobToken token;
    address owner;
    address deployer;
    address randomPerson;

    function setUp() public {
        deployer = address(this);
        owner = address(0x123); // Set owner address
        randomPerson = address(0x456); // Set owner address
        token = new NoobToken(owner);
    }

    function testMinting() public {
        vm.prank(randomPerson);
        // Attempt to mint tokens with the non-owner account
        vm.expectRevert();
        token.mint(deployer, 123);
        uint256 initialBalance = token.balanceOf(deployer);
        uint256 mintAmount = 1000 * 10 ** token.decimals(); // Mint 1000 tokens
        vm.prank(owner);
        token.mint(deployer, mintAmount);
        uint256 finalBalance = token.balanceOf(deployer);

        assertTrue(
            finalBalance == initialBalance + mintAmount,
            "Minting failed"
        );
    }

    function testMaxSupply() public {
        uint256 maxSupply = token.maxSupply();
        uint256 currentSupply = token.totalSupply();
        uint256 remainingTokens = maxSupply - currentSupply;

        assertTrue(remainingTokens > 0, "No remaining tokens");

        // Try to mint more than remaining tokens
        uint256 mintAmount = remainingTokens + 1;
        vm.prank(owner);
        try token.mint(deployer, mintAmount) {
            assertTrue(false, "Minting should fail");
        } catch Error(string memory) {
            assertTrue(true, "Minting failed as expected");
        }
    }
}
