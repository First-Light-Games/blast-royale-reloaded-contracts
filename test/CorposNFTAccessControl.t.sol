// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CorposNFT.sol";

contract CorposNFTAccessControlTest is Test {
    using Strings for uint256;
    bytes32 public constant ADMIN_ROLE = 0x00;
    // bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint96 FEE_DENOMINATOR = 10000;

    CorposNFT public tokenMock;
    uint96 public constant DEFAULT_ROYALTY_FEE_NUMERATOR = 1000;

    string public constant baseTokenURI = "https://www.test.com/";
    string public constant suffixURI = ".json";

    address user1 = vm.addr(0x1);
    address adminAddress = vm.addr(0xa);
    address nonAdminAddress = vm.addr(0xb);

    address royaltyReceiver = address(this);
    address minterAddress = address(this);
    address newMinterAddress = vm.addr(0x2);

    function setUp() public {
        tokenMock = new CorposNFT(
            adminAddress,
            royaltyReceiver,
            DEFAULT_ROYALTY_FEE_NUMERATOR,
            "Test",
            "TEST",
            baseTokenURI,
            suffixURI
        );
        
        vm.prank(adminAddress);
        tokenMock.setupMinter(address(minterAddress), true);
    }

    function testSetBaseURI() public {
        string memory baseTokenURInew = "https://www.test2.com/";
        vm.startPrank(adminAddress);
        tokenMock.setBaseURI(baseTokenURInew);
        assertEq(tokenMock.baseTokenURI(), baseTokenURInew);
        vm.stopPrank();
    }

    function testFailSetBaseURI() public {
        vm.prank(nonAdminAddress);
        string memory baseTokenURInew = "https://www.test2.com/";
        tokenMock.setBaseURI(baseTokenURInew);
    }

    function testSetSuffixURI() public {
        string memory setSuffixURInew = ".json2";
        vm.startPrank(adminAddress);
        tokenMock.setSuffixURI(setSuffixURInew);
        assertEq(tokenMock.suffixURI(), setSuffixURInew);
        vm.stopPrank();
    }

    function testFailSetSuffixURI() public {
        vm.prank(nonAdminAddress);
        string memory setSuffixURInew = ".json2";
        tokenMock.setSuffixURI(setSuffixURInew);
    }

    function testSafeMint() public {
        tokenMock.safeMint(user1, 0);
        assertEq(tokenMock.ownerOf(0), user1);
    }

    function testFailSafeMint() public {
        vm.startPrank(user1);
        tokenMock.safeMint(user1, 0);
    }

    function testHasRole() public {
        tokenMock.hasRole(MINTER_ROLE, minterAddress);
        tokenMock.hasRole(ADMIN_ROLE, adminAddress);
    }

    function testIsMinter() public {
        bool isMinter = tokenMock.isMinter(minterAddress);
        assertEq(isMinter, true);
    }

    function testNotIsMinter() public {
        bool isMinter = tokenMock.isMinter(user1);
        assertEq(isMinter, false);
    }

    function testIsAdmin() public {
        bool isAdmin = tokenMock.isAdmin(adminAddress);
        assertEq(isAdmin, true);
    }

    function testNotIsAdmin() public {
        bool isAdmin = tokenMock.isAdmin(user1);
        assertEq(isAdmin, false);
    }

    function testRevokeMinter() public {
        vm.startPrank(adminAddress);
        tokenMock.setupMinter(minterAddress, false);
        vm.stopPrank();
        bool isMinter = tokenMock.isMinter(minterAddress);
        assertEq(isMinter, false);
    }

    function testGrantNewMinter() public {
        vm.startPrank(adminAddress);
        tokenMock.setupMinter(newMinterAddress, true);
        vm.stopPrank();
        bool isMinter = tokenMock.isMinter(newMinterAddress);
        assertEq(isMinter, true);
    }
}
