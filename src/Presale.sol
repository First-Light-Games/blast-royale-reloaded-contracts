// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";


contract Presale is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public PaymentToken;
    IERC20 public NoobToken;
    bytes32 public MerkleRoot;
    mapping(address => uint256) public Purchased;
    uint256 public BuyPrice = 1;
    bool public USDCMutex;

    event NoobPurchased(address user, uint256 amount, uint256 buyPrice);

    constructor(IERC20 _paymentToken, IERC20 _noobToken, bytes32 root) Ownable(msg.sender) {
        NoobToken = _noobToken;
        MerkleRoot = root;
        PaymentToken = _paymentToken;
    }

    function AmountPurchased() external view returns (uint256) {
        return Purchased[msg.sender];
    }

    function Buy(bytes32[] calldata proof, uint256 amount, uint256 maxAmount) payable external nonReentrant {
        uint256 finalPrice = BuyPrice * amount;
        _verifyProof(proof, msg.sender, MerkleRoot, maxAmount);
        require(PaymentToken.balanceOf(msg.sender) >= finalPrice, "Not enough COIN to buy");
        _recordPurchase(amount, maxAmount);
        PaymentToken.transferFrom(msg.sender, address(this), finalPrice);
        emit NoobPurchased(msg.sender, amount, BuyPrice);
    }

    function _recordPurchase(uint256 amount, uint256 maxAmount) private {
        uint256 purchased = Purchased[msg.sender];
        require(purchased + amount <= maxAmount, "Insuficient allocation to purchase");
        Purchased[msg.sender] = purchased + amount;
    }

    function _verifyProof(bytes32[] memory proof, address addr, bytes32 root, uint256 amount) private pure {   
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, amount))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    }

    function UpdateMerkle(bytes32 root) external onlyOwner {
        MerkleRoot = root;
    }

    function UpdateBuyPrice(uint256 price) external onlyOwner {
        BuyPrice = price;
    }

    function UpdatePaymentToken(IERC20 paymentToken) external onlyOwner {
        PaymentToken = paymentToken;
    }
}