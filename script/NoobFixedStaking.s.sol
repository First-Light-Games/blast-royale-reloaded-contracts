// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NoobStaking.sol";

contract NoobFixedStakingScript is Script {
    address public adminAddress = 0xd540AB459B33f1B45D948f3edFd1B4Bbd810fD6d;
    address public noobAddress = 0x7866fbB00a197d5abab0aB666F045C2caA879ffC;
    address public priceFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    uint256 public tgeStart = 1730282400;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NoobStaking fixedStaking = new NoobStaking( noobAddress, adminAddress, tgeStart, priceFeedAddress);

        vm.stopBroadcast();
    }
}
