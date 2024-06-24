//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract Voucher is EIP712 {
    string private constant SIGNING_DOMAIN = "FLG";
    string private constant SIGNATURE_VERSION = "1";
    address public adminAddress;

    constructor(address _adminAddress) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        adminAddress = _adminAddress;
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

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function SignEIP712(NFTVoucher calldata voucher) public view returns (bytes32) {
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
    function IsValidSignature(NFTVoucher calldata voucher) public view returns (bool) {
        bytes32 digest = SignEIP712(voucher);
        return ECDSA.recover(digest, voucher.signature) == adminAddress;
    }

    /// Parses Uint256 from byte32s
    function ParseUint256(bytes32[] memory data) public pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            array[i] = uint256(data[i]);
        }
        return array;
    }
}
