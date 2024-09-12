// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StandardToken is ERC20 {
  
    constructor(string memory name_, string memory symbol_, address owner, uint256 amt) ERC20(name_, symbol_) {
        _mint(owner, amt);
    }
}