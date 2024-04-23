// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract NoobToken is ERC20, Ownable, ERC20Burnable, ERC20Permit {
    uint256 private _maxSupply = 512000000 * 10 ** 18; // 512,000,000 tokens with 18 decimals
    uint8 private _decimals = 18;

    constructor(
        address _owner
    )
        ERC20("Blast Royale: Noob", "NOOB")
        ERC20Permit("Blast Royale: Noob")
        Ownable()
    {
        transferOwnership(_owner);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function mint(address account, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= _maxSupply, "Exceeds max supply");
        _mint(account, amount);
    }
}
