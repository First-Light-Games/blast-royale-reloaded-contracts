// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NoobFlexibleStaking.sol";
import "../src/NoobToken.sol";

contract NoobFlexibleStakingScript is Script {
    address public adminAddress = 0xd540AB459B33f1B45D948f3edFd1B4Bbd810fD6d;
    address public noobAddress = 0x7866fbB00a197d5abab0aB666F045C2caA879ffC;
    uint256 public tgeStart = 1731402000; // 13/11 12:00 UTC

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NoobFlexibleStaking flexibleStaking = new NoobFlexibleStaking( noobAddress, 36500, adminAddress, tgeStart);

        vm.stopBroadcast();
    }
}
