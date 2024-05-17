//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MockNFT} from "../src/MockNFT.sol";

contract LazyNFTMinter is EIP712, AccessControl {
    string private constant SIGNING_DOMAIN = "FLG";
    string private constant SIGNATURE_VERSION = "1";
    uint64 private constant SIGNATURE_TYPE_NFT = 1;
    address public adminAddress;
    MockNFT public nftContract;

    constructor(address _adminAddress) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        adminAddress = _adminAddress;
        nftContract = new MockNFT();
    }

    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain.
    /// A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        // uuid
        bytes16 voucherId;
        // tokenIds
        bytes32[] data;
        // redeemer
        address wallet;
        // for nft voucher, signatureType = 1
        uint64 signatureType;
        /// @notice the EIP-712 signature of all other fields in the NFTVoucher struct.
        /// For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(NFTVoucher calldata voucher) public returns (uint256) {
        address signer = _verify(voucher);

        require(signer == adminAddress, "Signature invalid or unauthorized");
        require(uint64(voucher.signatureType) == SIGNATURE_TYPE_NFT, "Incorrect signature type");

        for (uint256 i = 0; i < voucher.data.length; i++) {
            uint256 tokenId = uint256(voucher.data[i]);
            nftContract.safeMint(voucher.wallet, tokenId);
        }

        return voucher.data.length;
    }

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("NFTVoucher(bytes16 voucherId,bytes32[] data,address wallet,uint64 signatureType)"),
                    voucher.voucherId,
                    keccak256(abi.encodePacked(voucher.data)),
                    voucher.wallet,
                    voucher.signatureType
                )
            )
        );
    }

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid.
    /// Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }
}
