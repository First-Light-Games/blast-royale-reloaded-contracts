// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BurnNFT} from "../src/BurnNFT.sol";
import {ERC721MOperatorFilterer} from "../src/ERC721MOperatorFilterer/contracts/ERC721MOperatorFilterer.sol";
import {IERC721A} from "../src/ERC721MOperatorFilterer/erc721a/contracts/IERC721A.sol";

contract NFTTest is Test {
    BurnNFT public burnNFTContract;
    ERC721MOperatorFilterer public corposNFTContract;

    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address deadAddress = address(0x000000000000000000000000000000000000dEaD);

    uint256 numOfNFTUser1 = 10;

    event NFTBurned(address indexed owner, uint256 indexed tokenId);

    function setUp() public {
        corposNFTContract = new ERC721MOperatorFilterer(
            "Blast Royale: Corpos", "blast_royale", ".json", 888, 0, 0x194Ea7ce80b510d6B872B1D221C6230eBF83bFF9, 120
        );
        burnNFTContract = new BurnNFT(address(corposNFTContract));
    }

    function mintNFTForUser1() public {
        corposNFTContract.ownerMint(uint32(numOfNFTUser1), user1);
        assertEq(corposNFTContract.balanceOf(user1), numOfNFTUser1);
    }

    function testBulkBurnWithoutApproval() public {
        mintNFTForUser1();
        vm.startPrank(user1);

        uint256[] memory ids = new uint256[](numOfNFTUser1);
        for (uint256 i = 0; i < numOfNFTUser1; i++) {
            ids[i] = uint256(i);
            assertEq(corposNFTContract.ownerOf(i), user1);
        }
        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);

        burnNFTContract.bulkBurn(ids);
        vm.stopPrank();
    }

    function testBulkBurn() public {
        mintNFTForUser1();
        vm.startPrank(user1);
        corposNFTContract.setApprovalForAll(address(burnNFTContract), true);

        uint256[] memory ids = new uint256[](numOfNFTUser1);
        for (uint256 i = 0; i < numOfNFTUser1; i++) {
            ids[i] = uint256(i);
            assertEq(corposNFTContract.ownerOf(i), user1);
        }
        burnNFTContract.bulkBurn(ids);

        vm.stopPrank();

        for (uint256 i = 0; i < numOfNFTUser1; i++) {
            assertEq(corposNFTContract.ownerOf(i), deadAddress);
        }
        uint256[] memory burnedIds = burnNFTContract.getBurnedIds(user1);
        // uint256[] memory burnedIds = burnNFTContract.burnedIds(user1);

        for (uint256 i = 0; i < burnedIds.length; i++) {
            assertEq(burnedIds[i], ids[i]);
        }
    }

    function testBulkBurnOnBehalfOfOwners() public {
        corposNFTContract.ownerMint(uint32(1), user1);
        corposNFTContract.ownerMint(uint32(2), user2);
        assertEq(corposNFTContract.ownerOf(0), user1);
        assertEq(corposNFTContract.ownerOf(1), user2);
        assertEq(corposNFTContract.ownerOf(2), user2);

        vm.startPrank(user1);
        corposNFTContract.setApprovalForAll(address(burnNFTContract), true);
        vm.stopPrank();

        vm.startPrank(user2);
        corposNFTContract.setApprovalForAll(address(burnNFTContract), true);
        vm.stopPrank();

        vm.startPrank(user3);
        uint256[] memory ids = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            ids[i] = uint256(i);
        }
        burnNFTContract.bulkBurn(ids);
        vm.stopPrank();

        assertEq(corposNFTContract.ownerOf(0), deadAddress);
        assertEq(corposNFTContract.ownerOf(1), deadAddress);
        assertEq(corposNFTContract.ownerOf(2), deadAddress);
    }

    function testFailBurnAgain() public {
        mintNFTForUser1();
        vm.startPrank(user1);
        corposNFTContract.setApprovalForAll(address(burnNFTContract), true);

        uint256[] memory ids = new uint256[](numOfNFTUser1);
        for (uint256 i = 0; i < numOfNFTUser1; i++) {
            ids[i] = uint256(i);
            assertEq(corposNFTContract.ownerOf(i), user1);
        }
        burnNFTContract.bulkBurn(ids);
        burnNFTContract.bulkBurn(ids);

        vm.stopPrank();
    }

    function testBurnEvent() public {
        mintNFTForUser1();
        vm.startPrank(user1);

        corposNFTContract.setApprovalForAll(address(burnNFTContract), true);

        uint256[] memory ids = new uint256[](numOfNFTUser1);
        for (uint256 i = 0; i < numOfNFTUser1; i++) {
            ids[i] = uint256(i);
            assertEq(corposNFTContract.ownerOf(i), user1);

            vm.expectEmit(true, true, false, true, address(burnNFTContract));
            emit NFTBurned(user1, i);
        }
        burnNFTContract.bulkBurn(ids);

        vm.stopPrank();
    }
}
