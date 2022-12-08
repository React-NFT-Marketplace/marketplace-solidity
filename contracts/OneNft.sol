// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC721, ERC721Permit } from "@soliditylabs/erc721-permit/contracts/ERC721Permit.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStoragePermit is ERC721Permit {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

contract OneNFT is ERC721URIStoragePermit {
    using Counters for Counters.Counter;
    address owner;
    // address operator;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    Counters.Counter private _nextTokenId;

    function getCurrentId() public view returns (uint256) {
        return _nextTokenId.current();
    }

    constructor(string memory name, string memory symbol) ERC721Permit(name, symbol) {
        owner = msg.sender;
        // token id 0 hv higher gas fee, so skip 0
    }

    // function getOperator() public view returns (address) {
    //     return operator;
    // }

    // function updateOperator(address _operator) public {
    //     require(owner == msg.sender, "Only owner can update operator");
    //     operator = _operator;
    // }

    function mint(string memory _tokenURI) external returns(uint) {
        _nextTokenId.increment();
        uint currentId = _nextTokenId.current();
        _safeMint(msg.sender, currentId);
        _setTokenURI(currentId, _tokenURI);
        return(currentId);
    }

    function mintTo(address receiver, string memory _tokenURI) external returns(uint) {
        _nextTokenId.increment();
        uint currentId = _nextTokenId.current();
        _safeMint(receiver, currentId);
        _setTokenURI(currentId, _tokenURI);
        return(currentId);
    }

    function safeTransferFromWithPermit(
        address from,
        address to,
        uint256 tokenId,
        uint256 deadline,
        bytes memory signature
    ) external {
        _safeTransferFromWithPermit(from, to, tokenId, deadline, signature);
    }

    function _safeTransferFromWithPermit(
        address from,
        address to,
        uint256 tokenId,
        uint256 deadline,
        bytes memory signature
    ) internal {
        _permit(msg.sender, tokenId, deadline, signature);
        // safeTransferFrom(from, to, tokenId, "");
        _transfer(from, to, tokenId);
    }
}