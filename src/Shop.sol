//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";


import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ShopLog is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 ShopCurrency; 

    uint256 public MinPurchase;

    constructor(IERC20 shopCurrency, address owner) Ownable(owner) {
        ShopCurrency = shopCurrency;
        MinPurchase = 10;
    }

    mapping(address => uint256) public purchases;

    event PurchaseIntentCreated(address indexed buyer, uint64 gameId, bytes32 metadata, uint256 price);

    function setMinPurchase(uint256 min) public nonReentrant onlyOwner {
        MinPurchase = min;
    }

    function IntentPurchase(uint64 gameId, bytes32 metadata, uint256 price) public whenNotPaused nonReentrant {
        require(price >= MinPurchase, "Price lower than min purchase amount");
        require(ShopCurrency.balanceOf(msg.sender) >= price, "Not enough funds");
        ShopCurrency.safeTransferFrom(msg.sender, address(this), price);
        purchases[msg.sender] += price;
        emit PurchaseIntentCreated(msg.sender, gameId, metadata, price);
    }
}
