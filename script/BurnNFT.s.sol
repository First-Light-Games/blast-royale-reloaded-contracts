// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/BurnNFT.sol";

contract BurnNFTScript is Script {
    address public nftContractAddress = 0xE560248353Aadf5b8b3703593B2Ac228F660674A;
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BurnNFT burnNFTContract = new BurnNFT(nftContractAddress);

        vm.stopBroadcast();
    }
}
