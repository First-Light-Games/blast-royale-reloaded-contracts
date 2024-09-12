// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LazyERC20Distributor} from "../src/LazyERC20Distributor.sol";

import {Voucher} from "../src/Voucher.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "MERC20") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LazyERC20DistributorTest is Test {
    using ECDSA for bytes32;

    string private constant SIGNING_DOMAIN = "FLG";
    string private constant SIGNATURE_VERSION = "1";

    LazyERC20Distributor public lazyERC20DistributorContract;
    MockERC20 public mockERC20;

    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address deadAddress = address(0x000000000000000000000000000000000000dEaD);

    uint256 internal nonAdminPrivateKey;
    uint256 internal adminPrivateKey;
    uint256 internal ownerPrivateKey;

    address internal nonAdmin;
    address internal admin;
    address internal owner;

    // EIP712 Domain Separator data
    bytes32 private DOMAIN_SEPARATOR;

    // EIP712 domain separator typehash
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    function setUp() public {
        nonAdminPrivateKey = 0xA11CE;
        adminPrivateKey = 0xB0B;
        ownerPrivateKey = 0x234;

        nonAdmin = vm.addr(nonAdminPrivateKey);
        admin = vm.addr(adminPrivateKey);
        owner = vm.addr(ownerPrivateKey);

        mockERC20 = new MockERC20();

        vm.startPrank(admin);
        lazyERC20DistributorContract = new LazyERC20Distributor(admin, owner);

        mockERC20.mint(address(lazyERC20DistributorContract), 1000);
        vm.stopPrank();

        vm.prank(owner);
        lazyERC20DistributorContract.whitelistToken(1, address(mockERC20));

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
                address(lazyERC20DistributorContract)
            )
        );
    }

    // computes the hash of a permit
    function getStructHash(
        bytes16 voucherId,
        bytes32[] memory data,
        address wallet,
        uint64 signatureType
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "NFTVoucher(bytes16 voucherId,bytes32[] data,address wallet,uint64 signatureType)"
                    ),
                    voucherId,
                    keccak256(abi.encodePacked(data)),
                    wallet,
                    signatureType
                )
            );
    }

    function getSignMessage(
        bytes16 voucherId,
        bytes32[] memory data,
        address wallet,
        uint64 signatureType
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(voucherId, data, wallet, signatureType)
                )
            );
    }

    function testRedeem() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](1);
        data[0] = bytes32(uint256(1000));
        address wallet = user2;
        uint64 signatureType = 1;

        bytes32 digestMessage = getSignMessage(
            voucherId,
            data,
            wallet,
            signatureType
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            adminPrivateKey,
            digestMessage
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        LazyERC20Distributor.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        lazyERC20DistributorContract.redeem(voucher);

        assertEq(mockERC20.balanceOf(user2), 1000);

        vm.expectRevert(bytes("Voucher had been used"));
        lazyERC20DistributorContract.redeem(voucher);

        // test not whitelisted token

        bytes16 voucherId2 = bytes16(uint128(2));
        bytes32[] memory data2 = new bytes32[](1);
        data2[0] = bytes32(uint256(1000));
        address wallet2 = user2;
        uint64 signatureType2 = 2;

        bytes32 digestMessage2 = getSignMessage(
            voucherId2,
            data2,
            wallet2,
            signatureType2
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            adminPrivateKey,
            digestMessage2
        );
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        LazyERC20Distributor.NFTVoucher memory voucher2 = Voucher.NFTVoucher({
            voucherId: voucherId2,
            data: data2,
            wallet: wallet2,
            signatureType: signatureType2,
            signature: signature2
        });

        vm.expectRevert(bytes("Token is not whitelisted"));
        lazyERC20DistributorContract.redeem(voucher2);

        // test insufficient token
        bytes16 voucherId3 = bytes16(uint128(3));
        bytes32[] memory data3 = new bytes32[](1);
        data3[0] = bytes32(uint256(1000));
        address wallet3 = user2;
        uint64 signatureType3 = 1;

        bytes32 digestMessage3 = getSignMessage(
            voucherId3,
            data3,
            wallet3,
            signatureType3
        );
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(
            adminPrivateKey,
            digestMessage3
        );
        bytes memory signature3 = abi.encodePacked(r3, s3, v3);

        LazyERC20Distributor.NFTVoucher memory voucher3 = Voucher.NFTVoucher({
            voucherId: voucherId3,
            data: data3,
            wallet: wallet3,
            signatureType: signatureType3,
            signature: signature3
        });

        vm.expectRevert(bytes("Insufficient token balance in contract"));
        lazyERC20DistributorContract.redeem(voucher3);

        mockERC20.mint(address(lazyERC20DistributorContract), 1000);
        lazyERC20DistributorContract.redeem(voucher3);
    }

    function testRedeemInvalidSigner() public {
        bytes16 voucherId = bytes16(uint128(1));
        bytes32[] memory data = new bytes32[](1);
        data[0] = bytes32(uint256(10));

        address wallet = user2;
        uint64 signatureType = 1;

        bytes32 digestMessage = getSignMessage(
            voucherId,
            data,
            wallet,
            signatureType
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            nonAdminPrivateKey,
            digestMessage
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        LazyERC20Distributor.NFTVoucher memory voucher = Voucher.NFTVoucher({
            voucherId: voucherId,
            data: data,
            wallet: wallet,
            signatureType: signatureType,
            signature: signature
        });

        vm.expectRevert(bytes("Signature invalid or unauthorized"));

        lazyERC20DistributorContract.redeem(voucher);

        // test change signer
        vm.prank(owner);
        lazyERC20DistributorContract.setSignerAddress(nonAdmin);
        mockERC20.mint(address(lazyERC20DistributorContract), 10);
        lazyERC20DistributorContract.redeem(voucher);
    }

    function testWithdraw() public {
        assertEq(
            mockERC20.balanceOf(address(lazyERC20DistributorContract)),
            1000
        );
        vm.prank(owner);
        lazyERC20DistributorContract.withdrawToken(1);
        assertEq(mockERC20.balanceOf(address(lazyERC20DistributorContract)), 0);

        vm.expectRevert(bytes("TokenId is invalid"));
        vm.prank(owner);
        lazyERC20DistributorContract.withdrawToken(2);
    }
}
