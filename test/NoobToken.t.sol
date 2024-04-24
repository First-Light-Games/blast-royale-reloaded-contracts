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
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                randomPerson
            )
        );
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
        uint256 maxSupply = token.cap();
        uint256 currentSupply = token.totalSupply();
        uint256 remainingTokens = maxSupply - currentSupply;

        assertTrue(remainingTokens > 0, "No remaining tokens");

        //attempt minting more than the cap
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20ExceededCap(uint256,uint256)",
                remainingTokens + 1,
                maxSupply
            )
        );
        token.mint(deployer, remainingTokens + 1);
    }
}
