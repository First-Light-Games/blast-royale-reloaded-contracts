// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/BurnForRewards.sol";
import "../src/interfaces/IERC20Burnable.sol";
import "../src/interfaces/IERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockCS is ERC20, ERC20Burnable, Ownable {
    constructor(
        address initialOwner
    ) ERC20("MyToken", "MTK") Ownable(initialOwner) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract MockERC721Burnable is ERC721, ERC721Burnable, Ownable {
    constructor(
        address initialOwner
    ) ERC721("MyToken", "MTK") Ownable(initialOwner) {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
}

contract BurnForRewardsTest is Test {
    BurnForRewards public burnForRewards;
    MockCS public craftSpice;
    MockERC721Burnable public blastEquipment;

    address public admin = address(1);
    address public user = address(2);
    address public user1 = address(3);
    address public user2 = address(4);

    function setUp() public {
        craftSpice = new MockCS(admin);
        blastEquipment = new MockERC721Burnable(admin);
        burnForRewards = new BurnForRewards(
            address(blastEquipment),
            address(craftSpice)
        );

        // Grant admin role to deployer
        burnForRewards.grantRole(burnForRewards.DEFAULT_ADMIN_ROLE(), admin);

        vm.startPrank(admin);
        // Mint tokens for user
        craftSpice.mint(user, 1000);
        craftSpice.mint(user1, 1000);
        craftSpice.mint(user2, 1000);
        blastEquipment.safeMint(user, 0);
        blastEquipment.safeMint(user, 1);
        blastEquipment.safeMint(user, 2);
        blastEquipment.safeMint(user1, 3);
        blastEquipment.safeMint(user1, 4);
        blastEquipment.safeMint(user1, 5);
        blastEquipment.safeMint(user2, 6);
        blastEquipment.safeMint(user2, 7);
        // Set user balance
        vm.deal(user, 1 ether);
        vm.stopPrank();
    }

    function testBurnAssetsForRewards() public {
        assertEq(craftSpice.balanceOf(user1), 1000);
        assertEq(blastEquipment.balanceOf(user1), 3);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256 csAmount = 100;

        uint256[] memory tokenIds_ = new uint256[](0);
        uint256[] memory tokenIds__ = new uint256[](1);
        tokenIds__[0] = 2;

        // Approve tokens
        vm.prank(user);
        craftSpice.approve(address(burnForRewards), 100);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.prank(user);
            blastEquipment.approve(address(burnForRewards), tokenIds[i]);
        }

        // Burn assets for BlastBucks reward
        vm.prank(user);
        burnForRewards.burnAssetsForRewards(
            tokenIds,
            csAmount,
            BurnForRewards.Reward.BlastBucks
        );

        // burn again with just cs
        vm.prank(user);
        craftSpice.approve(address(burnForRewards), 100);
        vm.prank(user);
        burnForRewards.burnAssetsForRewards(
            tokenIds_,
            100,
            BurnForRewards.Reward.BlastBucks
        );

        // burn again with just nfts
        vm.prank(user);
        blastEquipment.approve(address(burnForRewards), 2);
        vm.prank(user);
        burnForRewards.burnAssetsForRewards(
            tokenIds__,
            0,
            BurnForRewards.Reward.BlastBucks
        );

        BurnForRewards.BurntAssets memory burntAssets = burnForRewards
            .getBurntAssets(user);
        assertEq(burntAssets.csAmountForBB, 200);
        assertEq(burntAssets.equipmentIdsForBB.length, 3);
        assertEq(burntAssets.equipmentIdsForBB[0], 0);
        assertEq(burntAssets.equipmentIdsForBB[1], 1);
        assertEq(burntAssets.equipmentIdsForBB[2], 2);

        // Ensure tokens are burnt
        assertEq(craftSpice.balanceOf(user), 800);
        assertEq(blastEquipment.balanceOf(user), 0);

        // -------- test for burning for noob -------
        uint256[] memory tokenIds1 = new uint256[](2);
        tokenIds1[0] = 3;
        tokenIds1[1] = 4;
        uint256 csAmount1 = 100;

        uint256[] memory tokenIds1_ = new uint256[](0);
        uint256[] memory tokenIds1__ = new uint256[](1);
        tokenIds1__[0] = 5;

        // burn with just cs
        vm.prank(user1);
        craftSpice.approve(address(burnForRewards), 100);
        vm.prank(user1);
        burnForRewards.burnAssetsForRewards(
            tokenIds1_,
            100,
            BurnForRewards.Reward.Noob
        );

        // burn again with just nfts
        vm.prank(user1);
        blastEquipment.approve(address(burnForRewards), 5);
        vm.prank(user1);
        burnForRewards.burnAssetsForRewards(
            tokenIds1__,
            0,
            BurnForRewards.Reward.Noob
        );

        // Approve tokens
        vm.prank(user1);
        craftSpice.approve(address(burnForRewards), 100);

        for (uint256 i = 0; i < tokenIds1.length; i++) {
            vm.prank(user1);
            blastEquipment.approve(address(burnForRewards), tokenIds1[i]);
        }

        // Burn assets for BlastBucks reward
        vm.prank(user1);
        burnForRewards.burnAssetsForRewards(
            tokenIds1,
            csAmount1,
            BurnForRewards.Reward.Noob
        );

        BurnForRewards.BurntAssets memory burntAssets1 = burnForRewards
            .getBurntAssets(user1);
        assertEq(burntAssets1.csAmountForNoob, 200);
        assertEq(burntAssets1.equipmentIdsForNoob.length, 3);
        assertEq(burntAssets1.equipmentIdsForNoob[0], 5);
        assertEq(burntAssets1.equipmentIdsForNoob[1], 3);
        assertEq(burntAssets1.equipmentIdsForNoob[2], 4);

        // Ensure tokens are burnt
        assertEq(craftSpice.balanceOf(user1), 800);
        assertEq(blastEquipment.balanceOf(user1), 0);
    }

    function testPause() public {
        // Pause the contract
        vm.prank(admin);
        burnForRewards.pause(true);

        // Try to burn assets while paused
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256 csAmount = 100;

        vm.prank(user);
        craftSpice.approve(address(burnForRewards), csAmount);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.prank(user);
            blastEquipment.approve(address(burnForRewards), tokenIds[i]);
        }

        vm.prank(user);
        vm.expectRevert();
        burnForRewards.burnAssetsForRewards(
            tokenIds,
            csAmount,
            BurnForRewards.Reward.BlastBucks
        );

        // Unpause the contract
        vm.prank(admin);
        burnForRewards.pause(false);

        // Try to burn assets while unpaused
        vm.prank(user);
        burnForRewards.burnAssetsForRewards(
            tokenIds,
            csAmount,
            BurnForRewards.Reward.BlastBucks
        );

        BurnForRewards.BurntAssets memory burntAssets = burnForRewards
            .getBurntAssets(user);
        assertEq(burntAssets.csAmountForBB, csAmount);
        assertEq(burntAssets.equipmentIdsForBB.length, 2);
    }
}
