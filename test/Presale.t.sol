// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Presale} from "../src/Presale.sol";
import {StandardToken} from "../src/StandardToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PresaleTest is Test {
    Presale public presale;
    StandardToken public Token;
    StandardToken public USD;
    uint256 MaxTokens = 100000000000000;
    uint256 AmtToBuy = 666;
    address public UserWallet = address(0x7Ac410F4E36873022b57821D7a8EB3D7513C045a); 
    address public AdminWallet = address(0x2222222222222222222222222222222222222222); 
    bytes32 public MerkleTreeRoot = 0x6545d0ea0dc70d0e6fbecbebf81e3957f455eb24bae7b0a1daea07af8dce774a;

    function setUp() public {
        Token = new StandardToken("Noob", "Nb", AdminWallet, MaxTokens);
        USD = new StandardToken("USDC", "USD", AdminWallet, MaxTokens);
        presale = new Presale(USD, Token, MerkleTreeRoot); 
        vm.prank(UserWallet);
        USD.approve(address(presale), 1000000);
    }

    function GetProof() public returns (bytes32[] memory)  {
        bytes32 [] memory  proofs = new bytes32[](4);
        proofs[0] = 0x1287d940ed9b1ce75b3ba783a08ab4a625bab944848b67dd46991e6509432d4d;
        proofs[1] = 0xeb466f0a5f8bcd36870fefa9e98e4beab068c6dca8a383927a5a0e939ae8ddb8;
        proofs[2] = 0xe58c8b4a345985f5628b0c8ed0b04ab430f31bdb0f3afe06b3c5a64b55f6235c;
        proofs[3] = 0xdba6a4fb61d33a036f5a547dc4a9694ecbcc2b2319d3652e4a9b3b5b6e8a28db;
        return proofs;
    }

    function test_no_coins() public {
        vm.deal(UserWallet, 0);
        vm.prank(UserWallet);

        vm.expectRevert("Not enough COIN to buy");
        presale.Buy(GetProof(), AmtToBuy, AmtToBuy);
    }

    function test_no_claims() public {
        vm.deal(UserWallet, 0);
        vm.prank(UserWallet);

        assertEq(0, presale.AmountPurchased());
    }

    function test_no_whitelist() public {
        vm.prank(AdminWallet);
      
        bytes32[] memory proof =  new bytes32[](1);
      
        vm.expectRevert("Invalid proof");
        presale.Buy(proof, 10, 10);
    }

    function test_buy_success() public {
        vm.deal(UserWallet, 1000);
        vm.prank(AdminWallet);
      
        USD.transfer(UserWallet, AmtToBuy);

        vm.prank(UserWallet);
        presale.Buy(GetProof(), AmtToBuy, AmtToBuy);

        vm.prank(UserWallet);
        assertEq(AmtToBuy, presale.AmountPurchased());
    }

     function testFuzz_buyRandom(uint256 buyAmount, uint256 available) public {
        vm.deal(UserWallet, 123123);

        vm.prank(AdminWallet);

        if(available > MaxTokens) {
            return; // fuck it
        }

        USD.transfer(UserWallet, available);

        if(buyAmount != AmtToBuy) {
            vm.expectRevert("Invalid proof");
        }
        else if(buyAmount > available) {
            vm.expectRevert("Not enough COIN to buy");
        } 

        vm.prank(UserWallet);
        presale.Buy(GetProof(), buyAmount, buyAmount);

        if(buyAmount <= available && buyAmount == AmtToBuy) {
            vm.prank(UserWallet);
            assertEq(buyAmount, presale.AmountPurchased());
        } else {
             assertEq(0, presale.AmountPurchased());
        }
    }

}