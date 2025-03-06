// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BurnNFT} from "../src/BurnNFT.sol";
import {ShopLog} from "../src/Shop.sol";
import {ERC721MOperatorFilterer} from "../src/ERC721MOperatorFilterer/contracts/ERC721MOperatorFilterer.sol";
import {IERC721A} from "../src/ERC721MOperatorFilterer/erc721a/contracts/IERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "MERC20") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ShopTests is Test {
    ShopLog public shopContract;
    MockERC20 public noobToken;
    address public account = 0x7Ac410F4E36873022b57821D7a8EB3D7513C045a;


    function setUp() public {
        noobToken = new MockERC20();
        shopContract = new ShopLog(noobToken, account);
        vm.startPrank(account);
    }

    function testShopCaseSimple() public {
        noobToken.mint(account, 30);
        noobToken.approve(address(shopContract), 30);
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 30);

        uint256 purchased = shopContract.purchases(account);
        assertEq(uint256(30), purchased);
    }

      function testSummingResults() public {
        noobToken.mint(account, 100);
        noobToken.approve(address(shopContract), 30);
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 30);

         noobToken.approve(address(shopContract), 30);
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 30);

        uint256 purchased = shopContract.purchases(account);
        assertEq(uint256(60), purchased);
    }

    function testWithoutApproval() public {
      
        noobToken.mint(account, 30);
        vm.expectRevert();
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 30);

        uint256 purchased = shopContract.purchases(account);
        assertEq(uint256(0), purchased);
    }


    function testLowerMinPurchase() public {
      
        noobToken.mint(account, 1);
        noobToken.approve(address(shopContract), 1);
        vm.expectRevert();
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 1);

        uint256 purchased = shopContract.purchases(account);
        assertEq(uint256(0), purchased);
    }

    function testAllowingMinPurchase() public {
      
        noobToken.mint(account, 1);
        noobToken.approve(address(shopContract), 1);
        shopContract.setMinPurchase(0);
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 1);

        uint256 purchased = shopContract.purchases(account);
        assertEq(uint256(1), purchased);
    }

    function testWithoutNoobFunds() public {

        noobToken.approve(address(shopContract), 30);
        vm.expectRevert();
        shopContract.IntentPurchase(15, 0x000000000000000000000000000000000000000000000000000000000000f000, 30);

        uint256 purchased = shopContract.purchases(account);
        assertEq(uint256(0), purchased);
    }
}
