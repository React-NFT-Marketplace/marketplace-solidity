// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Tradable.sol";

contract OneNFT is ERC721Tradable {

    constructor(string memory name_, string memory symbol_, address _proxyRegistryAddress) ERC721Tradable(name_, symbol_, _proxyRegistryAddress) {  }

    function baseTokenURI() override public pure returns (string memory) {
    }

    function contractURI() public pure returns (string memory) {
    }
}