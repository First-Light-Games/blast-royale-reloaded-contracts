// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
contract GameItems is ERC1155, ERC2771Context, Ownable {
    string private baseURI;

    event Mint(address indexed to, uint256 indexed id, uint256 amount);

    mapping(uint256 => bool) private _exists;

    constructor(
        address _trustedForwarder,
        address _owner,
        string memory _uri
    )
        ERC1155(string(abi.encodePacked(_uri)))
        ERC2771Context(_trustedForwarder)
        Ownable(_owner)
    {
        baseURI = _uri;
    }

    function _msgSender()
        internal
        view
        override(Context, ERC2771Context)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(Context, ERC2771Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        if (!_exists[id]) {
            _exists[id] = true;
        }
        _mint(to, id, amount, data);
        emit Mint(to, id, amount);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists[_id], "URI: nonexistent token");
        return string(abi.encodePacked(baseURI, Strings.toString(_id))); // Use Strings.toString
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }
}
