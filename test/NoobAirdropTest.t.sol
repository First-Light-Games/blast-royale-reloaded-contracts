// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {NoobAirdrop} from "../src/NoobAirdrop.sol";
import {NoobToken} from "../src/NoobToken.sol";

contract NoobAirdropTest is Test {
    NoobToken public noobToken;
    NoobAirdrop public noobAirdrop;
    address public alice = address(0x1);
    address public owner = address(0x99);

    mapping(address => bool) public bitmap;

    function setUp() public {
        bytes32 merkleRoot = 0xa363ce445148603408e6b99e5f58271a80b194bfce04d7270672f0ac98e086f5;
        vm.startPrank(owner);
        noobToken = new NoobToken(owner);
        noobAirdrop = new NoobAirdrop(merkleRoot, noobToken, owner);
        noobToken.mint(address(noobAirdrop), 512000000000000000000000000);
        vm.stopPrank();
    }

    function testClaimAirDrop() public {
        assertEq(noobAirdrop.claimed(0), false);
        bytes32[] memory proof = new bytes32[](3);
        proof[
            0
        ] = 0xbfdc70f4af1219d21cbf011973621eb006c2e83a711a0688f4521b49931a8b56;
        proof[
            1
        ] = 0x7ca6faf4b88bcbb77fcba940a8967af35fe4d4d316b8bd35dd233fc12bdb8a7a;
        proof[
            2
        ] = 0x06847bad5c5113e6739462332ba8640c2d04952cb924c71146eff9b955dbf46a;

        uint256 index = 0;
        uint256 amount = 10000000000000000000;

        assertEq(noobToken.balanceOf(alice), 0);

        vm.prank(alice);
        noobAirdrop.claimAirDrop(proof, index, amount);

        assertEq(noobToken.balanceOf(alice), 10000000000000000000);
        assertEq(noobAirdrop.claimed(0), true);
    }

    function testVerifyProof() public {
        bytes32[] memory proof = new bytes32[](3);
        // wrong proof
        proof[
            0
        ] = 0xbfdc70f4af1219d21cbf011973621eb006c2e83a711a0688f4521b49931a8b56;
        proof[
            1
        ] = 0x7ca6faf4b88bcbb77fcba940a8967af35fe4d4d316b8bd35dd233fc12bdb8a7a;
        proof[
            2
        ] = 0x06847bad5c5113e6739462332ba8640c2d04952cb924c71146eff9b955dbf46b;

        uint256 index = 0;
        uint256 amount = 10000000000000000000;

        assertEq(noobToken.balanceOf(alice), 0);

        // should not be able to verify
        vm.prank(alice);
        assertEq(noobAirdrop.verifyProof(proof, index, amount, alice), false);
    }
}
