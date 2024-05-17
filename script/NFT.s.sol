// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LazyNFTMinter.sol";

contract MyScript is Script {
    address public adminAddress = 0x7Ac410F4E36873022b57821D7a8EB3D7513C045a;
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LazyNFTMinter lazyNFTMinterContract = new LazyNFTMinter(adminAddress);

        vm.stopBroadcast();
    }
}
