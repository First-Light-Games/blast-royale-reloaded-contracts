// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {LazyNFTMinter} from "../src/LazyNFTMinter.sol";
import {Voucher} from "../src/Voucher.sol";

contract VoucherTest is Test {
    using ECDSA for bytes32;

    string private constant SIGNING_DOMAIN = "FLG";
    string private constant SIGNATURE_VERSION = "1";

    Voucher public VoucherContract;

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

        VoucherContract = new Voucher(admin);

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
                address(VoucherContract)
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

    function testValidSignature() public {
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

        Voucher.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        assertTrue(VoucherContract.IsValidSignature(voucher));
    }


    function testSignatureInvalid() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](1);
        data[0] = bytes32(uint256(0));

        address wallet = user2;
        uint64 signatureType = 1;

        bytes32 digestMessage = getSignMessage(voucherId, data, wallet, signatureType);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nonAdminPrivateKey, digestMessage);
        bytes memory signature = abi.encodePacked(r, s, v);

        Voucher.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });
        assertFalse(VoucherContract.IsValidSignature(voucher));
    }

    function getByte(bytes32 data, uint8 index) internal pure returns (uint8) {
        return uint8(uint256(data) >> (8 * index) & 0xFF);
    }

    function testPayloadSerialization() public {
        
        uint256[] memory payload = new uint256[](3);
        bytes32[] memory data = new bytes32[](3);

        payload[0] = 1;
        payload[1] = 254;
        payload[2] = 257;

        data[0] =  bytes32(payload[0]);
        data[1] =  bytes32(payload[1]);
        data[2] =  bytes32(payload[2]);

        console.logBytes32(data[0]);
        console.logBytes32(data[1]);
        console.logBytes32(data[2]);

        assertEq(0x0000000000000000000000000000000000000000000000000000000000000001, data[0]);
        assertEq(1, getByte(data[0], 0));

        assertEq(0x00000000000000000000000000000000000000000000000000000000000000fe, data[1]);
        assertEq(254, getByte(data[1], 0));

        assertEq(0x0000000000000000000000000000000000000000000000000000000000000101, data[2]);
        assertEq(1, getByte(data[2], 0));
        assertEq(1, getByte(data[2], 1));

        uint256[] memory parsedBack = VoucherContract.ParseUint256(data);

        assertEq(1, parsedBack[0]);
        assertEq(254, parsedBack[1]);
        assertEq(257, parsedBack[2]);
    }
}
