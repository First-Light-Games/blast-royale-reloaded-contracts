// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LazyNFTMinter.sol";
import {NoobAirdrop} from "../src/NoobAirdrop.sol";

contract NoobAirdropScript is Script {
    address public owner = 0xd540AB459B33f1B45D948f3edFd1B4Bbd810fD6d;
    address public noobToken = 0x7866fbB00a197d5abab0aB666F045C2caA879ffC;
    bytes32 public merkleRoot = "0x0000000000000000000000000000000000000000000000000000000000000000";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NoobAirdrop airdropContract = new NoobAirdrop(
            merkleRoot,
            noobToken,
            owner
        );

        vm.stopBroadcast();
    }
}