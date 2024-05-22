//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MockNFT} from "../src/MockNFT.sol";
import {Voucher} from "./Voucher.sol";


contract LazyNFTMinter is AccessControl, Voucher {
    uint64 private constant SIGNATURE_TYPE_NFT = 1;
    MockNFT public nftContract;

    constructor(address _adminAddress) Voucher(_adminAddress) {
        nftContract = new MockNFT();
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(NFTVoucher calldata voucher) public returns (uint256) {
        require(IsValidSignature(voucher), "Signature invalid or unauthorized");
        require(uint64(voucher.signatureType) == SIGNATURE_TYPE_NFT, "Incorrect signature type");

        for (uint256 i = 0; i < voucher.data.length; i++) {
            uint256 tokenId = uint256(voucher.data[i]);
            nftContract.safeMint(voucher.wallet, tokenId);
        }
        return voucher.data.length;
    }
}
