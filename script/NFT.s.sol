// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LazyNFTMinter.sol";

contract MyScript is Script {
    address public adminAddress = 0x7Ac410F4E36873022b57821D7a8EB3D7513C045a;
    address private _royaltyReceiver = 0x7Ac410F4E36873022b57821D7a8EB3D7513C045a;
    uint96 private _royaltyNumerator = 100;
    string _name = "Blast Royale: Corpos";
    string _symbol = "blast_royale";
    string _baseTokenURI = "ipfs://bafybeicjjnjeilpv3x5wkshnpa7h4iaqnni67ifudidjxvu4vu2l77xtvq";
    string _suffixURI = ".json";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CorposNFT nftContract = new CorposNFT( adminAddress, _royaltyReceiver, _royaltyNumerator, _name, _symbol, _baseTokenURI, _suffixURI);

        LazyNFTMinter lazyNFTMinterContract = new LazyNFTMinter(address(nftContract),
            adminAddress
        );

        nftContract.setupMinter(address(lazyNFTMinterContract), true);

        vm.stopBroadcast();
    }
}
