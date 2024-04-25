// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract NoobToken is ERC20, Ownable, ERC20Capped {
    using SafeERC20 for IERC20;

    constructor(
        address _owner
    ) ERC20("NOOB", "NOOB") ERC20Capped(512000000 * 10 ** 18) Ownable(_owner) {}

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
