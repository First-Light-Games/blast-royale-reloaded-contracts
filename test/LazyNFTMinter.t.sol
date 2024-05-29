// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {LazyNFTMinter} from "../src/LazyNFTMinter.sol";

import {MockNFT} from "../src/MockNFT.sol";
import {Voucher} from "../src/Voucher.sol";
import {CorposNFT} from "../src/CorposNFT.sol";

contract LazyNFTMinterTest is Test {
    using ECDSA for bytes32;

    string private constant SIGNING_DOMAIN = "FLG";
    string private constant SIGNATURE_VERSION = "1";

    address private _royaltyReceiver = 0x7Ac410F4E36873022b57821D7a8EB3D7513C045a;
    uint96 private _royaltyNumerator = 100;
    string _name = "Blast Royale: Corpos";
    string _symbol = "blast_royale";
    string _baseTokenURI = "ipfs://bafybeicjjnjeilpv3x5wkshnpa7h4iaqnni67ifudidjxvu4vu2l77xtvq";
    string _suffixURI = ".json";

    LazyNFTMinter public lazyNFTMinterContract;
    CorposNFT public mockNFT;

    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address deadAddress = address(0x000000000000000000000000000000000000dEaD);

    uint256 internal nonAdminPrivateKey;
    uint256 internal adminPrivateKey;

    address internal nonAdmin;
    address internal admin;

    // EIP712 Domain Separator data
    bytes32 private DOMAIN_SEPARATOR;

    // EIP712 domain separator typehash
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function setUp() public {
        nonAdminPrivateKey = 0xA11CE;
        adminPrivateKey = 0xB0B;

        nonAdmin = vm.addr(nonAdminPrivateKey);
        admin = vm.addr(adminPrivateKey);

        mockNFT = new CorposNFT(admin, _royaltyReceiver, _royaltyNumerator, _name, _symbol, _baseTokenURI, _suffixURI);

        lazyNFTMinterContract =
            new LazyNFTMinter(address(mockNFT), admin);
        
        vm.startPrank(admin);
        mockNFT.setupMinter(address(lazyNFTMinterContract), true);
        vm.stopPrank();


        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(SIGNING_DOMAIN)),
                keccak256(bytes(SIGNATURE_VERSION)),
                chainId,
                address(lazyNFTMinterContract)
            )
        );
    }

    // computes the hash of a permit
    function getStructHash(bytes16 voucherId, bytes32[] memory data, address wallet, uint64 signatureType)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("NFTVoucher(bytes16 voucherId,bytes32[] data,address wallet,uint64 signatureType)"),
                voucherId,
                keccak256(abi.encodePacked(data)),
                wallet,
                signatureType
            )
        );
    }

    function getSignMessage(bytes16 voucherId, bytes32[] memory data, address wallet, uint64 signatureType)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(voucherId, data, wallet, signatureType))
        );
    }

    function testRedeem() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](3);
        data[0] = bytes32(uint256(0));
        data[1] = bytes32(uint256(10));
        data[2] = bytes32(uint256(99));
        address wallet = user2;
        uint64 signatureType = 1;

        bytes32 digestMessage = getSignMessage(voucherId, data, wallet, signatureType);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digestMessage);
        bytes memory signature = abi.encodePacked(r, s, v);

        LazyNFTMinter.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        lazyNFTMinterContract.redeem(voucher);

        assertEq(mockNFT.ownerOf(0), wallet);
        assertEq(mockNFT.ownerOf(10), wallet);
        assertEq(mockNFT.ownerOf(99), wallet);
    }

    function testRedeemInvalidSigner() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](1);
        data[0] = bytes32(uint256(0));

        address wallet = user2;
        uint64 signatureType = 1;

        bytes32 digestMessage = getSignMessage(voucherId, data, wallet, signatureType);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nonAdminPrivateKey, digestMessage);
        bytes memory signature = abi.encodePacked(r, s, v);

        LazyNFTMinter.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        vm.expectRevert(bytes("Signature invalid or unauthorized"));

        lazyNFTMinterContract.redeem(voucher);
    }

    function testRedeemInvalidSignatureType() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](1);
        data[0] = bytes32(uint256(0));
        address wallet = user2;
        uint64 signatureType = 2;

        bytes32 digestMessage = getSignMessage(voucherId, data, wallet, signatureType);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digestMessage);
        bytes memory signature = abi.encodePacked(r, s, v);

        LazyNFTMinter.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        vm.expectRevert(bytes("Incorrect signature type"));
        lazyNFTMinterContract.redeem(voucher);
    }

    function testFailRedeemAgain() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](3);
        data[0] = bytes32(uint256(0));
        data[1] = bytes32(uint256(10));
        data[2] = bytes32(uint256(99));
        address wallet = user2;
        uint64 signatureType = 1;

        bytes32 digestMessage = getSignMessage(voucherId, data, wallet, signatureType);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digestMessage);
        bytes memory signature = abi.encodePacked(r, s, v);

        LazyNFTMinter.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        lazyNFTMinterContract.redeem(voucher);
        lazyNFTMinterContract.redeem(voucher);
    }
}
