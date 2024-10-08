// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NoobFlexibleStaking.sol";
import "../src/NoobToken.sol";

contract NoobFlexibleStakingScript is Script {
    address public adminAddress = 0xd540AB459B33f1B45D948f3edFd1B4Bbd810fD6d;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NoobToken noobToken = new NoobToken(adminAddress);

        NoobFlexibleStaking flexibleStaking = new NoobFlexibleStaking( address(noobToken), 36500, adminAddress);

        vm.stopBroadcast();
    }
}
